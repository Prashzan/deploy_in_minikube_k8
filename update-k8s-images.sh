#!/bin/bash

# Update Kubernetes manifests using envsubst
# Usage: ./update-k8s-images.sh <dockerhub-username> [image-tag]

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: ./update-k8s-images.sh <dockerhub-username> [image-tag]"
    echo "Example: ./update-k8s-images.sh prashzan v1.0"
    exit 1
fi

export DOCKERHUB_USERNAME=$1
export IMAGE_TAG=${2:-v1.0}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Updating Kubernetes Manifests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Docker Hub Username: ${DOCKERHUB_USERNAME}"
echo "Image Tag: ${IMAGE_TAG}"
echo ""

# Check if envsubst is installed
if ! command -v envsubst &> /dev/null; then
    echo -e "${YELLOW}envsubst not found. Installing...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y gettext-base
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gettext
    fi
fi

# Process each deployment file in-place
echo -e "${BLUE}Processing deployments...${NC}"

# City service
if [ -f "k8s/06-city-service-deployment.yaml" ]; then
    echo "Updating city-service..."
    envsubst < k8s/06-city-service-deployment.yaml > /tmp/city-temp.yaml
    mv /tmp/city-temp.yaml k8s/06-city-service-deployment.yaml
    echo -e "${GREEN}✓ city-service updated${NC}"
fi

# Weather service
if [ -f "k8s/08-weather-service-deployment.yaml" ]; then
    echo "Updating weather-service..."
    envsubst < k8s/08-weather-service-deployment.yaml > /tmp/weather-temp.yaml
    mv /tmp/weather-temp.yaml k8s/08-weather-service-deployment.yaml
    echo -e "${GREEN}✓ weather-service updated${NC}"
fi

# Frontend
if [ -f "k8s/10-frontend-deployment.yaml" ]; then
    echo "Updating frontend..."
    envsubst < k8s/10-frontend-deployment.yaml > /tmp/frontend-temp.yaml
    mv /tmp/frontend-temp.yaml k8s/10-frontend-deployment.yaml
    echo -e "${GREEN}✓ frontend updated${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ All manifests updated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Images now use:"
echo "  - ${DOCKERHUB_USERNAME}/city-service:${IMAGE_TAG}"
echo "  - ${DOCKERHUB_USERNAME}/weather-service:${IMAGE_TAG}"
echo "  - ${DOCKERHUB_USERNAME}/weather-frontend:${IMAGE_TAG}"
echo ""
echo "Next steps:"
echo "  kubectl apply -f k8s/"
echo ""
echo -e "${YELLOW}Note: Files now contain actual values.${NC}"
echo -e "${YELLOW}To revert: git checkout k8s/*-deployment.yaml${NC}"
echo ""