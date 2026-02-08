from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
import os
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenWeatherMap API for city search
API_KEY = os.getenv('OPENWEATHER_API_KEY', 'demo')

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for Kubernetes liveness/readiness probes"""
    return jsonify({'status': 'healthy', 'service': 'city-service'}), 200

@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe - checks if service can handle requests"""
    try:
        # Simple check - could be extended to check external dependencies
        return jsonify({'status': 'ready', 'service': 'city-service'}), 200
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        return jsonify({'status': 'not ready', 'error': str(e)}), 503

@app.route('/api/cities/search', methods=['GET'])
def search_cities():
    """
    Search for cities by name
    Query params: q (city name)
    """
    city_name = request.args.get('q', '')
    
    if not city_name:
        return jsonify({'error': 'City name required'}), 400
    
    try:
        logger.info(f"Searching for cities: {city_name}")
        
        # Using OpenWeatherMap Geocoding API
        url = f'http://api.openweathermap.org/geo/1.0/direct'
        params = {
            'q': city_name,
            'limit': 5,
            'appid': API_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        cities = response.json()
        
        # Format response
        result = []
        for city in cities:
            result.append({
                'name': city.get('name'),
                'country': city.get('country'),
                'state': city.get('state', ''),
                'lat': city.get('lat'),
                'lon': city.get('lon')
            })
        
        logger.info(f"Found {len(result)} cities")
        return jsonify(result), 200
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching cities: {e}")
        return jsonify({'error': f'Failed to fetch cities: {str(e)}'}), 500

@app.route('/api/cities/<city_name>', methods=['GET'])
def get_city(city_name):
    """
    Get city details by name
    """
    try:
        logger.info(f"Fetching city details: {city_name}")
        
        url = f'http://api.openweathermap.org/geo/1.0/direct'
        params = {
            'q': city_name,
            'limit': 1,
            'appid': API_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        cities = response.json()
        
        if not cities:
            return jsonify({'error': 'City not found'}), 404
        
        city = cities[0]
        result = {
            'name': city.get('name'),
            'country': city.get('country'),
            'state': city.get('state', ''),
            'lat': city.get('lat'),
            'lon': city.get('lon')
        }
        
        return jsonify(result), 200
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching city: {e}")
        return jsonify({'error': f'Failed to fetch city: {str(e)}'}), 500

if __name__ == '__main__':
    # For Kubernetes, we don't use debug mode
    # Port is standard 5001
    logger.info("Starting City Service on port 5001")
    app.run(host='0.0.0.0', port=5001, debug=False)
