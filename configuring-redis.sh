#!/bin/bash

# Deploy Redis and update weather service
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Adding Redis Caching to Weather App${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Check if DOCKERHUB_USERNAME is set
# if [ -z "$DOCKERHUB_USERNAME" ]; then
#     echo -e "${YELLOW}Enter your Docker Hub username:${NC}"
#     read DOCKERHUB_USERNAME
#     export DOCKERHUB_USERNAME
# fi

echo -e "${BLUE}[1/6] Deploying Redis...${NC}"
kubectl apply -f ./k8s/16-redis.yaml

echo "  Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n weather-app --timeout=120s 2>/dev/null || sleep 30

echo -e "${GREEN}✓ Redis deployed${NC}"
echo ""

echo -e "${BLUE}[2/6] Testing Redis connection...${NC}"
REDIS_POD=$(kubectl get pods -n weather-app -l app=redis -o jsonpath='{.items[0].metadata.name}')
REDIS_PING=$(kubectl exec -it $REDIS_POD -n weather-app -- redis-cli ping 2>/dev/null | tr -d '\r')

if [ "$REDIS_PING" = "PONG" ]; then
    echo -e "${GREEN}✓ Redis is responding${NC}"
else
    echo -e "${RED}✗ Redis not responding${NC}"
    exit 1
fi
echo ""