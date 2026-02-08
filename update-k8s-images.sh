#!/bin/bash

# Update Kubernetes manifests with your Docker Hub username
# Usage: ./update-k8s-images.sh <your-dockerhub-username>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./update-k8s-images.sh <your-dockerhub-username>"
    echo "Example: ./update-k8s-images.sh johndoe"
    exit 1
fi

DOCKERHUB_USERNAME=$1
VERSION=${2:-v1.0}

echo "Updating Kubernetes manifests with Docker Hub username: ${DOCKERHUB_USERNAME}"
echo "Using version: ${VERSION}"
echo ""

# Update city-service deployment
sed -i.bak "s|YOUR_DOCKERHUB_USERNAME/city-service:v1.0|${DOCKERHUB_USERNAME}/city-service:${VERSION}|g" k8s/06-city-service-deployment.yaml

# Update weather-service deployment  
sed -i.bak "s|YOUR_DOCKERHUB_USERNAME/weather-service:v1.0|${DOCKERHUB_USERNAME}/weather-service:${VERSION}|g" k8s/08-weather-service-deployment.yaml

# Update frontend deployment
sed -i.bak "s|YOUR_DOCKERHUB_USERNAME/weather-frontend:v1.0|${DOCKERHUB_USERNAME}/weather-frontend:${VERSION}|g" k8s/10-frontend-deployment.yaml

# Remove backup files
rm -f k8s/*.bak

echo "✓ Kubernetes manifests updated successfully!"
echo ""
echo "Updated files:"
echo "  - k8s/06-city-service-deployment.yaml"
echo "  - k8s/08-weather-service-deployment.yaml"
echo "  - k8s/10-frontend-deployment.yaml"
echo ""
echo "Next step: Update your API key in k8s/02-secrets.yaml"
echo "Then deploy: kubectl apply -f k8s/"
