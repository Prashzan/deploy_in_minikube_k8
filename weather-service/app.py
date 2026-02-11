from flask import Flask, jsonify, request
from flask_cors import CORS
import requests
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import time
import logging
import redis
import json

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

API_KEY = os.getenv('OPENWEATHER_API_KEY', 'demo')

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres-service'),
    'database': os.getenv('DB_NAME', 'weatherdb'),
    'user': os.getenv('DB_USER', 'weatheruser'),
    'password': os.getenv('DB_PASSWORD', 'weatherpass'),
    'port': os.getenv('DB_PORT', '5432')
}

# Redis Configuration
REDIS_HOST = os.getenv('REDIS_HOST', 'redis-service')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
CACHE_TTL = int(os.getenv('CACHE_TTL', '300'))

redis_client = None

def get_redis_client():
    """Get or create Redis client"""
    global redis_client
    if redis_client is None:
        try:
            redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                db=0,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            redis_client.ping()
            logger.info(f"✓ Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
        except Exception as e:
            logger.error(f"✗ Failed to connect to Redis: {e}")
            redis_client = None
    return redis_client

def get_db_connection():
    """Create database connection with retry"""
    max_retries = 10
    for attempt in range(max_retries):
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            return conn
        except psycopg2.OperationalError as e:
            if attempt < max_retries - 1:
                logger.warning(f"Database connection attempt {attempt+1} failed, retrying...")
                time.sleep(3)
            else:
                logger.error("✗ Database connection failed")
                raise e

def init_db():
    """Initialize database tables with migration"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Create table if not exists
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
        
        # Check if 'cached' column exists, if not add it (MIGRATION)
        cur.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='weather_searches' AND column_name='cached';
        """)
        
        if cur.fetchone() is None:
            logger.info("Adding 'cached' column to weather_searches table...")
            cur.execute("""
                ALTER TABLE weather_searches 
                ADD COLUMN cached BOOLEAN DEFAULT FALSE;
            """)
            logger.info("✓ Added 'cached' column")
        
        # Check if 'response_time_ms' column exists, if not add it
        cur.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='weather_searches' AND column_name='response_time_ms';
        """)
        
        if cur.fetchone() is None:
            logger.info("Adding 'response_time_ms' column to weather_searches table...")
            cur.execute("""
                ALTER TABLE weather_searches 
                ADD COLUMN response_time_ms INTEGER;
            """)
            logger.info("✓ Added 'response_time_ms' column")
        
        # Create indexes
        cur.execute("CREATE INDEX IF NOT EXISTS idx_city_name ON weather_searches(city_name);")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_searched_at ON weather_searches(searched_at);")
        
        conn.commit()
        cur.close()
        conn.close()
        logger.info("✓ Database initialized and migrated")
        return True
    except Exception as e:
        logger.error(f"✗ Database init error: {e}")
        return False

db_ready = False

@app.route('/health', methods=['GET'])
def health():
    """Liveness probe"""
    return jsonify({'status': 'healthy', 'service': 'weather-service'}), 200

@app.route('/ready', methods=['GET'])
def ready():
    """Readiness probe"""
    global db_ready
    
    if not db_ready:
        db_ready = init_db()
    
    redis_status = "disconnected"
    try:
        r = get_redis_client()
        if r and r.ping():
            redis_status = "connected"
    except:
        redis_status = "error"
    
    if db_ready:
        try:
            conn = get_db_connection()
            conn.close()
            return jsonify({
                'status': 'ready',
                'database': 'connected',
                'redis': redis_status,
                'cache_ttl': CACHE_TTL
            }), 200
        except Exception as e:
            return jsonify({'status': 'not ready', 'error': str(e)}), 503
    else:
        return jsonify({'status': 'not ready', 'database': 'not initialized'}), 503

@app.route('/api/weather', methods=['GET'])
def get_weather():
    """Get weather data with Redis caching"""
    start_time = time.time()
    
    city_name = request.args.get('city')
    if not city_name:
        return jsonify({'error': 'City name required'}), 400
    
    cache_key = f"weather:{city_name.lower()}"
    from_cache = False
    
    # Try cache first
    try:
        r = get_redis_client()
        if r:
            cached_data = r.get(cache_key)
            if cached_data:
                logger.info(f"🎯 CACHE HIT: {cache_key}")
                weather_data = json.loads(cached_data)
                weather_data['from_cache'] = True
                weather_data['cache_age_seconds'] = int(CACHE_TTL - (r.ttl(cache_key) or 0))
                response_time = int((time.time() - start_time) * 1000)
                weather_data['response_time_ms'] = response_time
                
                # Log cache hit to DB
                try:
                    conn = get_db_connection()
                    cur = conn.cursor()
                    cur.execute("""
                        INSERT INTO weather_searches 
                        (city_name, country, latitude, longitude, temperature, feels_like, 
                         humidity, pressure, weather_main, weather_description, wind_speed, 
                         cached, response_time_ms)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """, (
                        weather_data['city'], weather_data['country'],
                        weather_data['coordinates']['lat'], weather_data['coordinates']['lon'],
                        weather_data['temperature'], weather_data['feels_like'],
                        weather_data['humidity'], weather_data['pressure'],
                        weather_data['weather']['main'], weather_data['weather']['description'],
                        weather_data['wind']['speed'], True, response_time
                    ))
                    conn.commit()
                    cur.close()
                    conn.close()
                except Exception as db_error:
                    logger.error(f"Database error logging cache hit: {db_error}")
                
                return jsonify(weather_data), 200
            else:
                logger.info(f"❌ CACHE MISS: {cache_key}")
    except Exception as e:
        logger.warning(f"⚠️  Redis error: {e}")
    
    # Fetch from API
    try:
        logger.info(f"🌐 Fetching from API: {city_name}")
        url = 'https://api.openweathermap.org/data/2.5/weather'
        params = {'q': city_name, 'appid': API_KEY, 'units': 'metric'}
        
        api_response = requests.get(url, params=params, timeout=10)
        api_response.raise_for_status()
        data = api_response.json()
        
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
            'timestamp': datetime.now().isoformat(),
            'from_cache': False
        }
        
        response_time = int((time.time() - start_time) * 1000)
        weather_data['response_time_ms'] = response_time
        
        # Cache the result
        try:
            r = get_redis_client()
            if r:
                r.setex(cache_key, CACHE_TTL, json.dumps(weather_data))
                logger.info(f"💾 Cached: {cache_key} (TTL: {CACHE_TTL}s)")
        except Exception as e:
            logger.warning(f"⚠️  Cache store error: {e}")
        
        # Store in database
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO weather_searches 
                (city_name, country, latitude, longitude, temperature, feels_like, 
                 humidity, pressure, weather_main, weather_description, wind_speed, 
                 cached, response_time_ms)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                weather_data['city'], weather_data['country'],
                weather_data['coordinates']['lat'], weather_data['coordinates']['lon'],
                weather_data['temperature'], weather_data['feels_like'],
                weather_data['humidity'], weather_data['pressure'],
                weather_data['weather']['main'], weather_data['weather']['description'],
                weather_data['wind']['speed'], False, response_time
            ))
            conn.commit()
            cur.close()
            conn.close()
        except Exception as db_error:
            logger.error(f"Database error: {db_error}")
        
        return jsonify(weather_data), 200
        
    except requests.exceptions.RequestException as e:
        logger.error(f"API error: {e}")
        return jsonify({'error': f'Failed to fetch weather: {str(e)}'}), 500

@app.route('/api/cache/stats', methods=['GET'])
def cache_stats():
    """Get Redis cache statistics"""
    try:
        r = get_redis_client()
        if r:
            info = r.info()
            keys = r.keys('weather:*')
            
            stats = {
                'status': 'connected',
                'total_keys': r.dbsize(),
                'weather_keys': len(keys),
                'memory_used': info.get('used_memory_human'),
                'hits': info.get('keyspace_hits', 0),
                'misses': info.get('keyspace_misses', 0),
                'ttl_seconds': CACHE_TTL
            }
            return jsonify(stats), 200
        else:
            return jsonify({'status': 'disconnected', 'error': 'Redis not available'}), 503
    except Exception as e:
        return jsonify({'status': 'error', 'error': str(e)}), 500

@app.route('/api/cache/clear', methods=['POST'])
def clear_cache():
    """Clear all cache"""
    try:
        r = get_redis_client()
        if r:
            keys_before = r.dbsize()
            r.flushdb()
            logger.info(f"🗑️  Cache cleared ({keys_before} keys deleted)")
            return jsonify({
                'message': 'Cache cleared successfully',
                'keys_deleted': keys_before
            }), 200
        return jsonify({'error': 'Redis not available'}), 503
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/weather/history', methods=['GET'])
def get_history():
    """Get search history"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                city_name,
                country,
                temperature,
                COALESCE(cached, false) as cached,
                COALESCE(response_time_ms, 0) as response_time_ms,
                searched_at
            FROM weather_searches 
            ORDER BY searched_at DESC 
            LIMIT %s
        """, (limit,))
        
        results = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return jsonify(results), 200
        
    except Exception as e:
        logger.error(f"Database error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/weather/stats', methods=['GET'])
def get_stats():
    """Get performance statistics"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT 
                COUNT(*) as total_requests,
                SUM(CASE WHEN COALESCE(cached, false) THEN 1 ELSE 0 END) as cache_hits,
                SUM(CASE WHEN NOT COALESCE(cached, false) THEN 1 ELSE 0 END) as cache_misses,
                ROUND(AVG(CASE WHEN COALESCE(cached, false) THEN response_time_ms END), 2) as avg_cached_ms,
                ROUND(AVG(CASE WHEN NOT COALESCE(cached, false) THEN response_time_ms END), 2) as avg_api_ms
            FROM weather_searches
            WHERE searched_at > NOW() - INTERVAL '1 hour'
        """)
        
        perf = cur.fetchone()
        
        cur.close()
        conn.close()
        
        if perf and perf['total_requests'] > 0 and perf['avg_cached_ms'] and perf['avg_api_ms']:
            hit_rate = (perf['cache_hits'] / perf['total_requests']) * 100
            perf['hit_rate_percent'] = round(hit_rate, 2)
            speedup = perf['avg_api_ms'] / perf['avg_cached_ms']
            perf['cache_speedup'] = f"{round(speedup, 1)}x faster"
        
        return jsonify(perf), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("🚀 Starting Weather Service with Redis caching")
    init_db()
    app.run(host='0.0.0.0', port=5002, debug=False)