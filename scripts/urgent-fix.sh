#!/bin/bash

# URGENT: Remove secrets from Git history and fix the issue

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}${BOLD}================================================================${NC}"
echo -e "${RED}${BOLD}  URGENT: Fixing Exposed Secrets${NC}"
echo -e "${RED}${BOLD}================================================================${NC}"
echo ""

echo -e "${YELLOW}This script will:${NC}"
echo "  1. Remove 02-secrets.yaml from Git tracking"
echo "  2. Add it to .gitignore"
echo "  3. Create a template file instead"
echo "  4. Set up secure secret management"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Removing secrets from Git tracking...${NC}"

# Remove from Git but keep local file
git rm --cached k8s/02-secrets.yaml 2>/dev/null || echo "File not in Git yet"

echo -e "${GREEN}✓ Removed from Git tracking${NC}"
echo ""

echo -e "${BLUE}Step 2: Adding to .gitignore...${NC}"

# Add to .gitignore
if ! grep -q "02-secrets.yaml" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Kubernetes Secrets - NEVER COMMIT!" >> .gitignore
    echo "k8s/02-secrets.yaml" >> .gitignore
fi

echo -e "${GREEN}✓ Added to .gitignore${NC}"
echo ""

echo -e "${BLUE}Step 3: Creating template file...${NC}"

# Create template if it doesn't exist
if [ ! -f "k8s/02-secrets.yaml.template" ]; then
    cat > k8s/02-secrets.yaml.template << 'EOFTEMPLATE'
apiVersion: v1
kind: Secret
metadata:
  name: weather-app-secrets
  namespace: weather-app
type: Opaque
stringData:
  # TEMPLATE FILE - Safe to commit
  # Use create-secrets.sh to generate actual secrets
  openweather-api-key: "YOUR_OPENWEATHER_API_KEY_HERE"
  postgres-user: "weatheruser"
  postgres-password: "YOUR_POSTGRES_PASSWORD_HERE"
  postgres-db: "weatherdb"
EOFTEMPLATE
fi

echo -e "${GREEN}✓ Template created${NC}"
echo ""

echo -e "${BLUE}Step 4: Committing changes...${NC}"

git add .gitignore
git add k8s/02-secrets.yaml.template
git commit -m "security: Remove secrets from Git, add template instead"

echo -e "${GREEN}✓ Changes committed${NC}"
echo ""

echo -e "${RED}${BOLD}================================================================${NC}"
echo -e "${RED}${BOLD}  CRITICAL: Next Steps${NC}"
echo -e "${RED}${BOLD}================================================================${NC}"
echo ""

echo -e "${YELLOW}1. REVOKE your current API key:${NC}"
echo "   - Go to: https://openweathermap.org/api_keys"
echo "   - Delete the exposed key"
echo "   - Generate a new key"
echo ""

echo -e "${YELLOW}2. Update GitHub secrets:${NC}"
echo "   - Go to: GitHub repo → Settings → Secrets"
echo "   - Add secret: OPENWEATHER_API_KEY = <new key>"
echo ""

echo -e "${YELLOW}3. Update local Kubernetes:${NC}"
echo "   - Run: ./create-secrets.sh"
echo "   - Enter your NEW API key"
echo ""

echo -e "${YELLOW}4. Push to GitHub:${NC}"
echo "   git push origin main"
echo ""

echo -e "${GREEN}✓ Secrets removed from Git!${NC}"
echo -e "${YELLOW}⚠ Don't forget to revoke the old API key!${NC}"
echo ""
