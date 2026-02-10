#!/bin/bash

# Guide to set GitHub Actions secrets

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  GitHub Actions Secrets Setup Guide${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

echo -e "${YELLOW}You need to add these secrets to GitHub:${NC}"
echo ""
echo "1. Go to your GitHub repository"
echo "2. Click: Settings → Secrets and variables → Actions"
echo "3. Click: 'New repository secret'"
echo ""

echo -e "${BLUE}Required Secrets:${NC}"
echo ""
echo -e "${GREEN}Secret Name: OPENWEATHER_API_KEY${NC}"
echo "  Description: Your OpenWeather API key"
echo "  Get it from: https://openweathermap.org/api"
echo ""

echo -e "${GREEN}Secret Name: DOCKERHUB_USERNAME${NC}"
echo "  Description: Your Docker Hub username"
echo "  Example: johndoe"
echo ""

echo -e "${GREEN}Secret Name: DOCKERHUB_TOKEN${NC}"
echo "  Description: Docker Hub access token"
echo "  How to get:"
echo "    1. Login to hub.docker.com"
echo "    2. Account Settings → Security"
echo "    3. New Access Token"
echo ""

echo -e "${YELLOW}Optional (if deploying to cloud):${NC}"
echo ""
echo -e "${GREEN}Secret Name: POSTGRES_PASSWORD${NC}"
echo "  Description: PostgreSQL password"
echo "  Note: Only needed for production deployments"
echo ""

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  After adding secrets:${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo "  ✓ GitHub Actions can use them with: \${{ secrets.SECRET_NAME }}"
echo "  ✓ Secrets are encrypted and never exposed in logs"
echo "  ✓ Your API key stays secure"
echo ""
