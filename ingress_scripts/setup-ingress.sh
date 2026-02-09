#!/bin/bash

# Setup Ingress for Weather App
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Setting Up Ingress for Weather App${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Step 1: Enable Ingress addon
echo -e "${BLUE}[1/6] Enabling Ingress addon in Minikube...${NC}"
minikube addons enable ingress

echo ""
echo -e "${BLUE}[2/6] Waiting for Ingress controller to be ready...${NC}"
echo "  This may take 1-2 minutes..."

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo -e "${GREEN}✓ Ingress controller is ready!${NC}"
echo ""

# Step 3: Deploy Ingress
echo -e "${BLUE}[4/6] Deploying Ingress resource...${NC}"
kubectl apply -f k8s/13-ingress.yaml

echo -e "${GREEN}✓ Ingress deployed${NC}"
echo ""

# Step 4: Add to /etc/hosts
MINIKUBE_IP=$(minikube ip)
echo -e "${BLUE}[5/6] Adding weather.local to /etc/hosts...${NC}"
echo "  Minikube IP: $MINIKUBE_IP"

# Remove old entry if exists
if grep -q "weather.local" /etc/hosts 2>/dev/null; then
    echo "  Removing old entry..."
    sudo sed -i '/weather.local/d' /etc/hosts
fi

# Add new entry
echo "$MINIKUBE_IP weather.local" | sudo tee -a /etc/hosts > /dev/null
echo -e "${GREEN}✓ Added to /etc/hosts${NC}"
echo ""

# Step 5: Verify setup
echo -e "${BLUE}[6/6] Verifying Ingress setup...${NC}"

# Wait a bit for Ingress to be ready
sleep 5

# Check Ingress status
kubectl get ingress -n weather-app

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  ✓ Ingress Setup Complete!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

echo -e "${YELLOW}Access Points:${NC}"
echo "  Frontend:       http://weather.local"
echo "  City API:       http://weather.local/api/cities/search?q=London"
echo "  Weather API:    http://weather.local/api/weather?city=London"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update frontend to use Ingress"
echo "     Run: ./update-frontend.sh"
echo ""
echo "  2. Test Ingress"
echo "     Run: ./test-ingress.sh"
echo ""

echo -e "${YELLOW}Verify Ingress:${NC}"
echo "  curl http://weather.local"
echo "  curl http://weather.local/api/cities/search?q=Tokyo"
echo "  curl http://weather.local/api/weather?city=London"
echo ""
