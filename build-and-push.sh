#!/bin/bash

# Build and Push Docker Images to Docker Hub
# This script builds all microservices images and pushes them to Docker Hub

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Image Build and Push Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if DOCKERHUB_USERNAME is set
if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo -e "${YELLOW}DOCKERHUB_USERNAME environment variable not set.${NC}"
    read -p "Enter your Docker Hub username: " DOCKERHUB_USERNAME
    export DOCKERHUB_USERNAME
fi

echo -e "${GREEN}Using Docker Hub username: ${DOCKERHUB_USERNAME}${NC}"
echo ""

# Version tag
VERSION=${1:-v1.0}
echo -e "${GREEN}Building with version tag: ${VERSION}${NC}"
echo ""

# Login to Docker Hub
echo -e "${BLUE}Step 1: Logging in to Docker Hub...${NC}"
docker login
echo ""

# Build and push city-service
echo -e "${BLUE}Step 2: Building city-service...${NC}"
cd city-service
docker build -t ${DOCKERHUB_USERNAME}/city-service:${VERSION} .
docker tag ${DOCKERHUB_USERNAME}/city-service:${VERSION} ${DOCKERHUB_USERNAME}/city-service:latest
echo -e "${GREEN}✓ city-service built successfully${NC}"

echo -e "${BLUE}Pushing city-service to Docker Hub...${NC}"
docker push ${DOCKERHUB_USERNAME}/city-service:${VERSION}
docker push ${DOCKERHUB_USERNAME}/city-service:latest
echo -e "${GREEN}✓ city-service pushed successfully${NC}"
echo ""
cd ..

# Build and push weather-service
echo -e "${BLUE}Step 3: Building weather-service...${NC}"
cd weather-service
docker build -t ${DOCKERHUB_USERNAME}/weather-service:${VERSION} .
docker tag ${DOCKERHUB_USERNAME}/weather-service:${VERSION} ${DOCKERHUB_USERNAME}/weather-service:latest
echo -e "${GREEN}✓ weather-service built successfully${NC}"

echo -e "${BLUE}Pushing weather-service to Docker Hub...${NC}"
docker push ${DOCKERHUB_USERNAME}/weather-service:${VERSION}
docker push ${DOCKERHUB_USERNAME}/weather-service:latest
echo -e "${GREEN}✓ weather-service pushed successfully${NC}"
echo ""
cd ..

# Build and push frontend
echo -e "${BLUE}Step 4: Building frontend...${NC}"
cd frontend
docker build -t ${DOCKERHUB_USERNAME}/weather-frontend:${VERSION} .
docker tag ${DOCKERHUB_USERNAME}/weather-frontend:${VERSION} ${DOCKERHUB_USERNAME}/weather-frontend:latest
echo -e "${GREEN}✓ frontend built successfully${NC}"

echo -e "${BLUE}Pushing frontend to Docker Hub...${NC}"
docker push ${DOCKERHUB_USERNAME}/weather-frontend:${VERSION}
docker push ${DOCKERHUB_USERNAME}/weather-frontend:latest
echo -e "${GREEN}✓ frontend pushed successfully${NC}"
echo ""
cd ..

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All images built and pushed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Images created:"
echo "  - ${DOCKERHUB_USERNAME}/city-service:${VERSION}"
echo "  - ${DOCKERHUB_USERNAME}/weather-service:${VERSION}"
echo "  - ${DOCKERHUB_USERNAME}/weather-frontend:${VERSION}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update k8s/*.yaml files with your Docker Hub username"
echo "2. Run: ./update-k8s-images.sh ${DOCKERHUB_USERNAME}"
echo "3. Deploy to Kubernetes: kubectl apply -f k8s/"
echo ""
