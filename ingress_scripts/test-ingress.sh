#!/bin/bash

# Test Ingress setup
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Testing Ingress Configuration${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Test 1: Check /etc/hosts
echo -e "${BLUE}[Test 1] Checking /etc/hosts...${NC}"
if grep -q "weather.local" /etc/hosts; then
    WEATHER_IP=$(grep "weather.local" /etc/hosts | awk '{print $1}')
    echo -e "${GREEN}✓ weather.local found: $WEATHER_IP${NC}"
else
    echo -e "${RED}✗ weather.local not in /etc/hosts${NC}"
    echo "  Run: echo \"\$(minikube ip) weather.local\" | sudo tee -a /etc/hosts"
    exit 1
fi
echo ""

# Test 2: Check Ingress resource
echo -e "${BLUE}[Test 2] Checking Ingress resource...${NC}"
if kubectl get ingress weather-app-ingress -n weather-app &> /dev/null; then
    echo -e "${GREEN}✓ Ingress resource exists${NC}"
    kubectl get ingress weather-app-ingress -n weather-app
else
    echo -e "${RED}✗ Ingress resource not found${NC}"
    exit 1
fi
echo ""

# Test 3: Check Ingress controller
echo -e "${BLUE}[Test 3] Checking Ingress controller...${NC}"
CONTROLLER_READY=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [ "$CONTROLLER_READY" = "True" ]; then
    echo -e "${GREEN}✓ Ingress controller is ready${NC}"
else
    echo -e "${RED}✗ Ingress controller not ready${NC}"
    echo "  Run: kubectl get pods -n ingress-nginx"
    exit 1
fi
echo ""

# Test 4: Check services are ClusterIP
echo -e "${BLUE}[Test 4] Checking service types...${NC}"
CITY_TYPE=$(kubectl get svc city-service -n weather-app -o jsonpath='{.spec.type}')
WEATHER_TYPE=$(kubectl get svc weather-service -n weather-app -o jsonpath='{.spec.type}')
FRONTEND_TYPE=$(kubectl get svc frontend-service -n weather-app -o jsonpath='{.spec.type}')

if [ "$CITY_TYPE" = "ClusterIP" ] && [ "$WEATHER_TYPE" = "ClusterIP" ] && [ "$FRONTEND_TYPE" = "ClusterIP" ]; then
    echo -e "${GREEN}✓ All services are ClusterIP${NC}"
    echo "  city-service: $CITY_TYPE"
    echo "  weather-service: $WEATHER_TYPE"
    echo "  frontend-service: $FRONTEND_TYPE"
else
    echo -e "${YELLOW}⚠ Some services not ClusterIP:${NC}"
    echo "  city-service: $CITY_TYPE"
    echo "  weather-service: $WEATHER_TYPE"
    echo "  frontend-service: $FRONTEND_TYPE"
fi
echo ""

# Test 5: Test frontend
echo -e "${BLUE}[Test 5] Testing frontend (http://weather.local)...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://weather.local)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Frontend accessible (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Frontend not accessible (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# Test 6: Test City API
echo -e "${BLUE}[Test 6] Testing City API...${NC}"
CITY_RESPONSE=$(curl -s "http://weather.local/api/cities/search?q=London")
if echo "$CITY_RESPONSE" | grep -q "London"; then
    echo -e "${GREEN}✓ City API working${NC}"
    echo "$CITY_RESPONSE" | head -c 200
    echo "..."
else
    echo -e "${RED}✗ City API not working${NC}"
    echo "$CITY_RESPONSE"
fi
echo ""

# Test 7: Test Weather API
echo -e "${BLUE}[Test 7] Testing Weather API...${NC}"
WEATHER_RESPONSE=$(curl -s "http://weather.local/api/weather?city=London")
if echo "$WEATHER_RESPONSE" | grep -q "temperature"; then
    echo -e "${GREEN}✓ Weather API working${NC}"
    echo "$WEATHER_RESPONSE" | head -c 200
    echo "..."
else
    echo -e "${RED}✗ Weather API not working${NC}"
    echo "$WEATHER_RESPONSE"
fi
echo ""

# Summary
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  Test Summary${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo -e "${YELLOW}If all tests passed:${NC}"
echo "  ✓ Ingress is working correctly"
echo "  ✓ All APIs accessible via http://weather.local"
echo "  ✓ No need for NodePort or Minikube IP"
echo ""
echo -e "${YELLOW}Try in browser:${NC}"
echo "  http://weather.local"
echo ""
echo -e "${YELLOW}Try with curl:${NC}"
echo "  curl http://weather.local/api/cities/search?q=Tokyo"
echo "  curl http://weather.local/api/weather?city=Paris"
echo ""
