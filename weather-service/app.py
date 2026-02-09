from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import time
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API Configuration
API_KEY = os.getenv('OPENWEATHER_API_KEY', 'demo')

# Database Configuration - using Kubernetes service names
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres-service'),  # Kubernetes service name
    'database': os.getenv('DB_NAME', 'weatherdb'),
    'user': os.getenv('DB_USER', 'weatheruser'),
    'password': os.getenv('DB_PASSWORD', 'weatherpass'),
    'port': os.getenv('DB_PORT', '5432')
}

def get_db_connection():
    """Create database connection with retry logic"""
    max_retries = 10
    retry_delay = 3
    
    for attempt in range(max_retries):
        try:
            logger.info(f"Attempting database connection (attempt {attempt + 1}/{max_retries})")
            conn = psycopg2.connect(**DB_CONFIG)
            logger.info("Database connection successful")
            return conn
        except psycopg2.OperationalError as e:
            if attempt < max_retries - 1:
                logger.warning(f"Database connection failed: {e}. Retrying in {retry_delay}s...")
                time.sleep(retry_delay)
            else:
                logger.error(f"Database connection failed after {max_retries} attempts")
                raise e

def init_db():
    """Initialize database tables"""
    try:
        logger.info("Initializing database...")
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Create weather_searches table
        cur.execute("""
            CREATE TABLE IF NOT EXISTS weather_searches (
                id SERIAL PRIMARY KEY,
                city_name VARCHAR(100) NOT NULL,
                country VARCHAR(10),
                latitude DECIMAL(10, 6),
                longitude DECIMAL(10, 6),
                temperature DECIMAL(5, 2),
                feels_like DECIMAL(5, 2),
                humidity INTEGER,
                pressure INTEGER,
                weather_main VARCHAR(50),
                weather_description VARCHAR(100),
                wind_speed DECIMAL(5, 2),
                searched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        
        # Create indexes
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_city_name ON weather_searches(city_name);
        """)
        
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_searched_at ON weather_searches(searched_at);
        """)
        
        conn.commit()
        cur.close()
        conn.close()
        logger.info("Database initialized successfully!")
        return True
        
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        return False

# Global flag for readiness
db_ready = False

@app.route('/health', methods=['GET'])
def health():
    """Liveness probe - checks if application is running"""
    return jsonify({'status': 'healthy', 'service': 'weather-service'}), 200

@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe - checks if service can handle requests"""
    global db_ready
    
    if not db_ready:
        db_ready = init_db()
    
    if db_ready:
        try:
            # Quick DB connection check
            conn = get_db_connection()
            conn.close()
            return jsonify({'status': 'ready', 'service': 'weather-service', 'database': 'connected'}), 200
        except Exception as e:
            logger.error(f"Readiness check failed: {e}")
            return jsonify({'status': 'not ready', 'error': str(e)}), 503
    else:
        return jsonify({'status': 'not ready', 'error': 'Database not initialized'}), 503

@app.route('/api/weather', methods=['GET'])
def get_weather():
    """
    Get current weather for a city
    Query params: city (city name) OR lat & lon (coordinates)
    """
    city_name = request.args.get('city')
    lat = request.args.get('lat')
    lon = request.args.get('lon')
    
    if not city_name and not (lat and lon):
        return jsonify({'error': 'City name or coordinates required'}), 400
    
    try:
        logger.info(f"Fetching weather for: {city_name or f'lat={lat}, lon={lon}'}")
        
        # Fetch weather data from OpenWeatherMap
        url = 'https://api.openweathermap.org/data/2.5/weather'
        
        if city_name:
            params = {'q': city_name, 'appid': API_KEY, 'units': 'metric'}
        else:
            params = {'lat': lat, 'lon': lon, 'appid': API_KEY, 'units': 'metric'}
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # Extract weather information
        weather_data = {
            'city': data['name'],
            'country': data['sys']['country'],
            'coordinates': {
                'lat': data['coord']['lat'],
                'lon': data['coord']['lon']
            },
            'temperature': data['main']['temp'],
            'feels_like': data['main']['feels_like'],
            'humidity': data['main']['humidity'],
            'pressure': data['main']['pressure'],
            'weather': {
                'main': data['weather'][0]['main'],
                'description': data['weather'][0]['description'],
                'icon': data['weather'][0]['icon']
            },
            'wind': {
                'speed': data['wind']['speed']
            },
            'timestamp': datetime.now().isoformat()
        }
        
        # Store in database
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            
            cur.execute("""
                INSERT INTO weather_searches 
                (city_name, country, latitude, longitude, temperature, feels_like, 
                humidity, pressure, weather_main, weather_description, wind_speed)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                weather_data['city'],
                weather_data['country'],
                weather_data['coordinates']['lat'],
                weather_data['coordinates']['lon'],
                weather_data['temperature'],
                weather_data['feels_like'],
                weather_data['humidity'],
                weather_data['pressure'],
                weather_data['weather']['main'],
                weather_data['weather']['description'],
                weather_data['wind']['speed']
            ))
            
            conn.commit()
            cur.close()
            conn.close()
            
            logger.info(f"Weather data stored for {weather_data['city']}")
            
        except Exception as db_error:
            logger.error(f"Database error: {db_error}")
            # Continue even if database insert fails
        
        return jsonify(weather_data), 200
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching weather: {e}")
        return jsonify({'error': f'Failed to fetch weather data: {str(e)}'}), 500

@app.route('/api/weather/history', methods=['GET'])
def get_history():
    """
    Get search history from database
    Query params: limit (default 10), city (optional filter)
    """
    try:
        limit = request.args.get('limit', 10, type=int)
        city_filter = request.args.get('city')
        
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        if city_filter:
            cur.execute("""
                SELECT * FROM weather_searches 
                WHERE city_name ILIKE %s
                ORDER BY searched_at DESC 
                LIMIT %s
            """, (f'%{city_filter}%', limit))
        else:
            cur.execute("""
                SELECT * FROM weather_searches 
                ORDER BY searched_at DESC 
                LIMIT %s
            """, (limit,))
        
        results = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return jsonify(results), 200
        
    except Exception as e:
        logger.error(f"Database error: {e}")
        return jsonify({'error': f'Database error: {str(e)}'}), 500

@app.route('/api/weather/stats', methods=['GET'])
def get_stats():
    """
    Get statistics from database
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                COUNT(*) as total_searches,
                COUNT(DISTINCT city_name) as unique_cities,
                city_name as most_searched_city,
                COUNT(*) as search_count
            FROM weather_searches 
            GROUP BY city_name
            ORDER BY search_count DESC
            LIMIT 1
        """)
        
        stats = cur.fetchone()
        
        cur.close()
        conn.close()
        
        return jsonify(stats if stats else {}), 200
        
    except Exception as e:
        logger.error(f"Database error: {e}")
        return jsonify({'error': f'Database error: {str(e)}'}), 500

if __name__ == '__main__':
    logger.info("Starting Weather Service on port 5002")
    # Initialize database on startup
    init_db()
    app.run(host='0.0.0.0', port=5002, debug=False)
