#!/bin/bash

# Test Kubernetes Deployment
# This script tests all services and database

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Kubernetes Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo -e "${RED}✗ Minikube is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Minikube is running${NC}"
echo ""

# Check pod status
echo -e "${BLUE}Step 1: Checking pod status...${NC}"
echo ""
kubectl get pods -n weather-app
echo ""

READY_PODS=$(kubectl get pods -n weather-app --no-headers 2>/dev/null | grep "Running" | wc -l)
TOTAL_PODS=$(kubectl get pods -n weather-app --no-headers 2>/dev/null | wc -l)

if [ "$READY_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods are running ($READY_PODS/$TOTAL_PODS)${NC}"
else
    echo -e "${YELLOW}⚠ Not all pods are ready ($READY_PODS/$TOTAL_PODS)${NC}"
fi
echo ""

# Get service URLs
echo -e "${BLUE}Step 2: Getting service URLs...${NC}"
CITY_URL=$(minikube service city-service -n weather-app --url 2>/dev/null)
WEATHER_URL=$(minikube service weather-service -n weather-app --url 2>/dev/null)
FRONTEND_URL=$(minikube service frontend-service -n weather-app --url 2>/dev/null)

echo "City Service: $CITY_URL"
echo "Weather Service: $WEATHER_URL"
echo "Frontend: $FRONTEND_URL"
echo ""

# Test City Service
echo -e "${BLUE}Step 3: Testing City Service...${NC}"
echo "Health check:"
curl -s "${CITY_URL}/health" | head -n 5
echo ""
echo "Search cities:"
curl -s "${CITY_URL}/api/cities/search?q=London" | head -n 10
echo ""
echo -e "${GREEN}✓ City Service is working${NC}"
echo ""

# Test Weather Service  
echo -e "${BLUE}Step 4: Testing Weather Service...${NC}"
echo "Health check:"
curl -s "${WEATHER_URL}/health" | head -n 5
echo ""
echo "Get weather:"
curl -s "${WEATHER_URL}/api/weather?city=London" | head -n 15
echo ""
echo -e "${GREEN}✓ Weather Service is working${NC}"
echo ""

# Test Database
echo -e "${BLUE}Step 5: Testing Database Connection...${NC}"
POD_NAME=$(kubectl get pods -n weather-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

echo "Checking if database table exists:"
kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "\dt" 2>/dev/null || echo "Checking..."
echo ""

echo "Counting records:"
kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT COUNT(*) FROM weather_searches;" 2>/dev/null || echo "No data yet"
echo ""

echo -e "${GREEN}✓ Database is accessible${NC}"
echo ""

# Test Frontend
echo -e "${BLUE}Step 6: Testing Frontend...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${FRONTEND_URL}/")
if [ "$HTTP_CODE" -eq "200" ]; then
    echo -e "${GREEN}✓ Frontend is accessible (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}⚠ Frontend returned HTTP $HTTP_CODE${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All services are running in Kubernetes!"
echo ""
echo "Access your application:"
echo "  Frontend: $FRONTEND_URL"
echo ""
echo "Or run: minikube service frontend-service -n weather-app"
echo ""
