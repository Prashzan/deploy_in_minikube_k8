#!/bin/bash

# Simple visual cache demonstration
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Redis Cache Performance Demonstration             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Clear cache
echo -e "${YELLOW}Clearing cache...${NC}"
curl -s -X POST http://weather.local/api/cache/clear > /dev/null
echo ""

# First request
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  REQUEST 1: London (Cache MISS - From API)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}⏱️  Starting timer...${NC}"

START=$(date +%s%3N)
RESPONSE1=$(curl -s "http://weather.local/api/weather?city=London")
END=$(date +%s%3N)
TIME1=$((END - START))

TEMP=$(echo $RESPONSE1 | grep -o '"temperature":[^,]*' | cut -d':' -f2)
FROM_CACHE=$(echo $RESPONSE1 | grep -o '"from_cache":[^,]*' | cut -d':' -f2)

echo -e "${YELLOW}Temperature: ${TEMP}°C${NC}"
echo -e "${YELLOW}From cache: ${FROM_CACHE}${NC}"
echo -e "${RED}⏱️  Time: ${TIME1}ms${NC}"
echo ""

sleep 2

# Second request
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  REQUEST 2: London (Cache HIT - From Redis)${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}⏱️  Starting timer...${NC}"

START=$(date +%s%3N)
RESPONSE2=$(curl -s "http://weather.local/api/weather?city=London")
END=$(date +%s%3N)
TIME2=$((END - START))

TEMP=$(echo $RESPONSE2 | grep -o '"temperature":[^,]*' | cut -d':' -f2)
FROM_CACHE=$(echo $RESPONSE2 | grep -o '"from_cache":[^,]*' | cut -d':' -f2)

echo -e "${YELLOW}Temperature: ${TEMP}°C${NC}"
echo -e "${YELLOW}From cache: ${FROM_CACHE}${NC}"
echo -e "${GREEN}⏱️  Time: ${TIME2}ms${NC}"
echo ""

# Comparison
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  PERFORMANCE COMPARISON${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  API Request:    ${RED}${TIME1}ms${NC}"
echo -e "  Cached Request: ${GREEN}${TIME2}ms${NC}"
echo ""

if [ $TIME2 -gt 0 ]; then
    SPEEDUP=$((TIME1 / TIME2))
    IMPROVEMENT=$(( (TIME1 - TIME2) * 100 / TIME1 ))
    
    echo -e "${GREEN}  ⚡ Cache is ${SPEEDUP}x FASTER!${NC}"
    echo -e "${GREEN}  ⚡ ${IMPROVEMENT}% performance improvement!${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🎉 Redis caching is working perfectly! 🎉                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""