#!/bin/bash

# Deploy Weather App to Kubernetes
# This script deploys all components in the correct order

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deploying Weather App to Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo -e "${YELLOW}Minikube is not running. Starting Minikube...${NC}"
    minikube start
fi

echo -e "${GREEN}✓ Minikube is running${NC}"
echo ""

# Apply all Kubernetes manifests in order
echo -e "${BLUE}Step 1: Creating namespace...${NC}"
kubectl apply -f k8s/00-namespace.yaml
echo ""

echo -e "${BLUE}Step 2: Creating ConfigMap...${NC}"
kubectl apply -f k8s/01-configmap.yaml
echo ""

echo -e "${BLUE}Step 3: Creating Secrets...${NC}"
kubectl apply -f k8s/02-secrets.yaml
echo ""

echo -e "${BLUE}Step 4: Creating PersistentVolumeClaim...${NC}"
kubectl apply -f k8s/03-pvc.yaml
echo ""

echo -e "${BLUE}Step 5: Deploying PostgreSQL...${NC}"
kubectl apply -f k8s/04-postgres-deployment.yaml
kubectl apply -f k8s/05-postgres-service.yaml
echo ""

echo -e "${BLUE}Step 6: Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n weather-app --timeout=120s
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
echo ""

echo -e "${BLUE}Step 7: Deploying City Service...${NC}"
kubectl apply -f k8s/06-city-service-deployment.yaml
kubectl apply -f k8s/07-city-service-service.yaml
echo ""

echo -e "${BLUE}Step 8: Deploying Weather Service...${NC}"
kubectl apply -f k8s/08-weather-service-deployment.yaml
kubectl apply -f k8s/09-weather-service-service.yaml
echo ""

echo -e "${BLUE}Step 9: Deploying Frontend...${NC}"
kubectl apply -f k8s/10-frontend-deployment.yaml
kubectl apply -f k8s/11-frontend-service.yaml
echo ""

echo -e "${BLUE}Step 10: Waiting for deployments to be ready...${NC}"

# Wait for each deployment to complete rollout
kubectl rollout status deployment/city-service -n weather-app --timeout=180s
kubectl rollout status deployment/weather-service -n weather-app --timeout=180s
kubectl rollout status deployment/frontend -n weather-app --timeout=120s

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show deployment status
echo -e "${BLUE}Deployment Status:${NC}"
kubectl get pods -n weather-app
echo ""

echo -e "${BLUE}Services:${NC}"
kubectl get svc -n weather-app
echo ""

# Get Minikube URLs
echo -e "${GREEN}Access your application:${NC}"
echo ""
echo "Frontend:"
echo "  $(minikube service frontend-service -n weather-app --url)"
echo ""
echo "City Service:"
echo "  $(minikube service city-service -n weather-app --url)"
echo ""
echo "Weather Service:"
echo "  $(minikube service weather-service -n weather-app --url)"
echo ""
echo -e "${YELLOW}Tip: Use 'minikube service frontend-service -n weather-app' to open frontend in browser${NC}"
echo ""
