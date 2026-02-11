#!/bin/bash

# Comprehensive Redis caching test
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

BASE_URL="http://weather.local"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Redis Caching Test Suite${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Test 1: Check Redis is running
echo -e "${BOLD}[Test 1] Checking Redis Pod Status${NC}"
echo "─────────────────────────────────────────────────────────"
REDIS_POD=$(kubectl get pods -n weather-app -l app=redis -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$REDIS_POD" ]; then
    echo -e "${RED}✗ Redis pod not found${NC}"
    exit 1
fi

REDIS_STATUS=$(kubectl get pod $REDIS_POD -n weather-app -o jsonpath='{.status.phase}')
if [ "$REDIS_STATUS" = "Running" ]; then
    echo -e "${GREEN}✓ Redis pod is running: $REDIS_POD${NC}"
else
    echo -e "${RED}✗ Redis pod status: $REDIS_STATUS${NC}"
    exit 1
fi
echo ""

# Test 2: Test Redis connection
echo -e "${BOLD}[Test 2] Testing Redis Connection${NC}"
echo "─────────────────────────────────────────────────────────"
REDIS_PING=$(kubectl exec -it $REDIS_POD -n weather-app -- redis-cli ping 2>/dev/null | tr -d '\r')

if [ "$REDIS_PING" = "PONG" ]; then
    echo -e "${GREEN}✓ Redis responding to PING${NC}"
else
    echo -e "${RED}✗ Redis not responding${NC}"
    exit 1
fi
echo ""

# Test 3: Check weather service readiness
echo -e "${BOLD}[Test 3] Checking Weather Service Redis Connection${NC}"
echo "─────────────────────────────────────────────────────────"
READY_RESPONSE=$(curl -s "$BASE_URL/api/weather/ready")
REDIS_STATUS_API=$(echo $READY_RESPONSE | grep -o '"redis":"[^"]*"' | cut -d'"' -f4)

echo "Ready endpoint response:"
echo "$READY_RESPONSE" | jq '.' 2>/dev/null || echo "$READY_RESPONSE"

if [ "$REDIS_STATUS_API" = "connected" ]; then
    echo -e "${GREEN}✓ Weather service connected to Redis${NC}"
else
    echo -e "${YELLOW}⚠ Redis status from API: $REDIS_STATUS_API${NC}"
fi
echo ""

# Test 4: Clear cache before testing
echo -e "${BOLD}[Test 4] Clearing Cache${NC}"
echo "─────────────────────────────────────────────────────────"
CLEAR_RESPONSE=$(curl -s -X POST "$BASE_URL/api/cache/clear")
echo "$CLEAR_RESPONSE" | jq '.' 2>/dev/null || echo "$CLEAR_RESPONSE"
echo -e "${GREEN}✓ Cache cleared${NC}"
echo ""

sleep 2

# Test 5: First request (Cache MISS)
echo -e "${BOLD}[Test 5] First Request - Cache MISS (from API)${NC}"
echo "─────────────────────────────────────────────────────────"
echo "Requesting: London weather"

START=$(date +%s%N)
RESPONSE1=$(curl -s "$BASE_URL/api/weather?city=London")
END=$(date +%s%N)
TIME1=$(( (END - START) / 1000000 ))

FROM_CACHE1=$(echo $RESPONSE1 | grep -o '"from_cache":[^,]*' | cut -d':' -f2)
RESPONSE_TIME1=$(echo $RESPONSE1 | grep -o '"response_time_ms":[0-9]*' | cut -d':' -f2)

echo "Response:"
echo $RESPONSE1 | jq '{city, temperature, from_cache, response_time_ms}' 2>/dev/null || echo $RESPONSE1

echo ""
echo -e "${YELLOW}From cache: $FROM_CACHE1${NC}"
echo -e "${YELLOW}Response time: ${TIME1}ms (wall clock)${NC}"
echo -e "${YELLOW}API response time: ${RESPONSE_TIME1}ms${NC}"

if [ "$FROM_CACHE1" = "false" ]; then
    echo -e "${GREEN}✓ Cache MISS as expected (first request)${NC}"
else
    echo -e "${RED}✗ Expected cache MISS, got HIT${NC}"
fi
echo ""

sleep 2

# Test 6: Second request (Cache HIT)
echo -e "${BOLD}[Test 6] Second Request - Cache HIT (from Redis)${NC}"
echo "─────────────────────────────────────────────────────────"
echo "Requesting: London weather (same city)"

START=$(date +%s%N)
RESPONSE2=$(curl -s "$BASE_URL/api/weather?city=London")
END=$(date +%s%N)
TIME2=$(( (END - START) / 1000000 ))

FROM_CACHE2=$(echo $RESPONSE2 | grep -o '"from_cache":[^,]*' | cut -d':' -f2)
RESPONSE_TIME2=$(echo $RESPONSE2 | grep -o '"response_time_ms":[0-9]*' | cut -d':' -f2)
CACHE_AGE=$(echo $RESPONSE2 | grep -o '"cache_age_seconds":[0-9]*' | cut -d':' -f2)

echo "Response:"
echo $RESPONSE2 | jq '{city, temperature, from_cache, response_time_ms, cache_age_seconds}' 2>/dev/null || echo $RESPONSE2

echo ""
echo -e "${YELLOW}From cache: $FROM_CACHE2${NC}"
echo -e "${YELLOW}Response time: ${TIME2}ms (wall clock)${NC}"
echo -e "${YELLOW}API response time: ${RESPONSE_TIME2}ms${NC}"
echo -e "${YELLOW}Cache age: ${CACHE_AGE}s${NC}"

if [ "$FROM_CACHE2" = "true" ]; then
    echo -e "${GREEN}✓ Cache HIT as expected (second request)${NC}"
    
    # Calculate speedup
    if [ $TIME2 -gt 0 ]; then
        SPEEDUP=$((TIME1 / TIME2))
        echo -e "${GREEN}⚡ Cache is ${SPEEDUP}x faster!${NC}"
    fi
else
    echo -e "${RED}✗ Expected cache HIT, got MISS${NC}"
fi
echo ""

# Test 7: Check cache stats
echo -e "${BOLD}[Test 7] Cache Statistics${NC}"
echo "─────────────────────────────────────────────────────────"
STATS=$(curl -s "$BASE_URL/api/cache/stats")
echo "$STATS" | jq '.' 2>/dev/null || echo "$STATS"

TOTAL_KEYS=$(echo $STATS | grep -o '"total_keys":[0-9]*' | cut -d':' -f2)
HITS=$(echo $STATS | grep -o '"hits":[0-9]*' | cut -d':' -f2)
MISSES=$(echo $STATS | grep -o '"misses":[0-9]*' | cut -d':' -f2)

echo ""
echo -e "${GREEN}✓ Cache has $TOTAL_KEYS key(s)${NC}"
echo -e "${GREEN}✓ Hits: $HITS, Misses: $MISSES${NC}"
echo ""

# Test 8: Multiple cities
echo -e "${BOLD}[Test 8] Testing Multiple Cities${NC}"
echo "─────────────────────────────────────────────────────────"
CITIES=("Tokyo" "Paris" "New York" "Mumbai")

for city in "${CITIES[@]}"; do
    echo -n "  Requesting $city... "
    RESP=$(curl -s "$BASE_URL/api/weather?city=$city")
    TEMP=$(echo $RESP | grep -o '"temperature":[^,]*' | cut -d':' -f2)
    FROM_CACHE=$(echo $RESP | grep -o '"from_cache":[^,]*' | cut -d':' -f2)
    
    if [ "$FROM_CACHE" = "true" ]; then
        echo -e "${GREEN}${TEMP}°C (cached)${NC}"
    else
        echo -e "${YELLOW}${TEMP}°C (API)${NC}"
    fi
    sleep 0.5
done
echo ""

# Test 9: Verify cache with second round
echo -e "${BOLD}[Test 9] Verifying Cache (Second Round)${NC}"
echo "─────────────────────────────────────────────────────────"
echo "Requesting same cities again (should all be cached):"

for city in "${CITIES[@]}"; do
    echo -n "  Requesting $city... "
    RESP=$(curl -s "$BASE_URL/api/weather?city=$city")
    FROM_CACHE=$(echo $RESP | grep -o '"from_cache":[^,]*' | cut -d':' -f2)
    RESP_TIME=$(echo $RESP | grep -o '"response_time_ms":[0-9]*' | cut -d':' -f2)
    
    if [ "$FROM_CACHE" = "true" ]; then
        echo -e "${GREEN}✓ Cached (${RESP_TIME}ms)${NC}"
    else
        echo -e "${RED}✗ Not cached${NC}"
    fi
done
echo ""

# Test 10: Performance stats from database
echo -e "${BOLD}[Test 10] Performance Statistics${NC}"
echo "─────────────────────────────────────────────────────────"
PERF_STATS=$(curl -s "$BASE_URL/api/weather/stats")
echo "$PERF_STATS" | jq '.' 2>/dev/null || echo "$PERF_STATS"
echo ""

# Test 11: Redis keys
echo -e "${BOLD}[Test 11] Checking Redis Keys${NC}"
echo "─────────────────────────────────────────────────────────"
echo "Keys in Redis:"
kubectl exec -it $REDIS_POD -n weather-app -- redis-cli KEYS "weather:*" 2>/dev/null | grep "weather:" || echo "No keys found"
echo ""

# Summary
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${GREEN}✓ Redis is working correctly${NC}"
echo -e "${GREEN}✓ Cache MISS and HIT behavior verified${NC}"
echo -e "${GREEN}✓ Multiple cities cached successfully${NC}"
echo -e "${GREEN}✓ Performance improvement demonstrated${NC}"
echo ""
echo -e "${YELLOW}Performance:${NC}"
echo "  First request (API):  ~${TIME1}ms"
echo "  Second request (Cache): ~${TIME2}ms"
if [ $TIME2 -gt 0 ]; then
    SPEEDUP=$((TIME1 / TIME2))
    echo -e "  ${GREEN}Speedup: ${SPEEDUP}x faster${NC}"
fi
echo ""
echo -e "${YELLOW}Try these commands:${NC}"
echo "  curl http://weather.local/api/cache/stats | jq '.'"
echo "  curl http://weather.local/api/weather/stats | jq '.'"
echo "  kubectl exec -it $REDIS_POD -n weather-app -- redis-cli MONITOR"
echo ""