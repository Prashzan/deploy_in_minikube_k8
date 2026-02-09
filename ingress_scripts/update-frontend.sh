#!/bin/bash

# Update and rebuild frontend with Ingress support
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Updating Frontend for Ingress${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Check if DOCKERHUB_USERNAME is set
if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo -e "${YELLOW}Enter your Docker Hub username:${NC}"
    read DOCKERHUB_USERNAME
    export DOCKERHUB_USERNAME
fi

FRONTEND_DIR="../frontend"

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}Error: Frontend directory not found at $FRONTEND_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}[2/4] Building new Docker image...${NC}"
cd "$FRONTEND_DIR"
docker build -t $DOCKERHUB_USERNAME/weather-frontend:ingress .

echo -e "${GREEN}✓ Image built${NC}"
echo ""

echo -e "${BLUE}[3/4] Pushing to Docker Hub...${NC}"
docker push $DOCKERHUB_USERNAME/weather-frontend:ingress

echo -e "${GREEN}✓ Image pushed${NC}"
echo ""

echo -e "${BLUE}[4/4] Updating Kubernetes deployment...${NC}"
kubectl set image deployment/frontend \
  frontend=$DOCKERHUB_USERNAME/weather-frontend:ingress \
  -n weather-app

echo "Waiting for rollout..."
kubectl rollout status deployment/frontend -n weather-app

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✓ Frontend Updated!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

echo -e "${YELLOW}The frontend now uses:${NC}"
echo "  - Ingress routing (http://weather.local)"
echo "  - No hardcoded Minikube IP"
echo "  - Relative API paths (/api/cities, /api/weather)"
echo ""

echo -e "${YELLOW}Test it:${NC}"
echo "  Open: http://weather.local"
echo ""
