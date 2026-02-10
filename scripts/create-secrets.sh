#!/bin/bash

# Create Kubernetes secrets from environment variables
# This keeps secrets OUT of Git!

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Creating Kubernetes Secrets (Secure Method)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Check if secrets are set as environment variables
if [ -z "$OPENWEATHER_API_KEY" ]; then
    echo -e "${YELLOW}Enter your OpenWeather API Key:${NC}"
    read -s OPENWEATHER_API_KEY
    export OPENWEATHER_API_KEY
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${YELLOW}Enter PostgreSQL password (or press Enter for default):${NC}"
    read -s POSTGRES_PASSWORD
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD="weatherpass"
    fi
    export POSTGRES_PASSWORD
fi

echo ""
echo -e "${BLUE}Creating secrets in Kubernetes...${NC}"

# Create secret directly in Kubernetes (never written to file)
kubectl create secret generic weather-app-secrets \
  --from-literal=openweather-api-key="$OPENWEATHER_API_KEY" \
  --from-literal=postgres-user="weatheruser" \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=postgres-db="weatherdb" \
  --namespace=weather-app \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo -e "${GREEN}✓ Secrets created successfully!${NC}"
echo ""
echo -e "${YELLOW}Security Notes:${NC}"
echo "  ✓ Secrets stored only in Kubernetes (not in files)"
echo "  ✓ Secrets never committed to Git"
echo "  ✓ API key not visible in repository"
echo ""
echo -e "${YELLOW}To verify:${NC}"
echo "  kubectl get secret weather-app-secrets -n weather-app"
echo "  kubectl describe secret weather-app-secrets -n weather-app"
echo ""
