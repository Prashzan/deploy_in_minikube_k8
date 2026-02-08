#!/bin/bash

# CI/CD Setup Script
# This script helps you set up GitHub Actions for your repository

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Actions CI/CD Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if in git repository
if [ ! -d .git ]; then
    echo -e "${YELLOW}Not a git repository. Initializing...${NC}"
    git init
fi

# Copy workflow files
echo -e "${BLUE}Step 1: Setting up GitHub Actions workflows...${NC}"
mkdir -p .github/workflows
cp .github/workflows/*.yml .github/workflows/ 2>/dev/null || echo "Workflow files already exist"
cp .yamllint.yml . 2>/dev/null || echo "yamllint config already exists"

echo -e "${GREEN}✓ Workflow files copied${NC}"
echo ""

# Check for required secrets
echo -e "${BLUE}Step 2: Checking required secrets...${NC}"
echo ""
echo "You need to configure these GitHub Secrets:"
echo ""
echo "1. DOCKERHUB_USERNAME - Your Docker Hub username"
echo "2. DOCKERHUB_TOKEN - Docker Hub access token"
echo "3. OPENWEATHER_API_KEY - OpenWeatherMap API key"
echo ""
echo "How to add secrets:"
echo "  1. Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions"
echo "  2. Click 'New repository secret'"
echo "  3. Add each secret with the corresponding value"
echo ""

read -p "Press Enter after you've added the secrets..."

# Update image references in workflows
echo ""
echo -e "${BLUE}Step 3: Updating image references...${NC}"
read -p "Enter your Docker Hub username: " DOCKERHUB_USERNAME

if [ -n "$DOCKERHUB_USERNAME" ]; then
    # Update deployment files
    find k8s -name "*.yaml" -exec sed -i.bak "s/YOUR_DOCKERHUB_USERNAME/${DOCKERHUB_USERNAME}/g" {} \;
    
    # Clean up backup files
    find k8s -name "*.bak" -delete
    
    echo -e "${GREEN}✓ Image references updated${NC}"
else
    echo -e "${YELLOW}Skipping image reference update${NC}"
fi

# Commit changes
echo ""
echo -e "${BLUE}Step 4: Committing changes...${NC}"

git add .github/workflows/*.yml
git add .yamllint.yml
git add k8s/*.yaml 2>/dev/null || true

if git diff --cached --quiet; then
    echo -e "${YELLOW}No changes to commit${NC}"
else
    git commit -m "Add CI/CD pipeline with GitHub Actions"
    echo -e "${GREEN}✓ Changes committed${NC}"
fi

# Push to GitHub
echo ""
echo -e "${BLUE}Step 5: Pushing to GitHub...${NC}"
echo ""
echo "Current remote:"
git remote -v || echo "No remote configured"
echo ""

read -p "Do you want to push to GitHub now? (y/n): " push_confirm

if [ "$push_confirm" = "y" ]; then
    # Check if remote exists
    if git remote get-url origin > /dev/null 2>&1; then
        git push origin main || git push origin master
        echo -e "${GREEN}✓ Pushed to GitHub${NC}"
    else
        echo -e "${YELLOW}No remote 'origin' configured${NC}"
        read -p "Enter your GitHub repository URL (https://github.com/username/repo.git): " repo_url
        git remote add origin $repo_url
        git push -u origin main || git push -u origin master
        echo -e "${GREEN}✓ Pushed to GitHub${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Go to your GitHub repository"
echo "2. Click on 'Actions' tab"
echo "3. You should see your workflows listed"
echo "4. Make a commit to trigger the CI/CD pipeline!"
echo ""
echo "To trigger a manual deployment:"
echo "  GitHub → Actions → Manual Deploy → Run workflow"
echo ""
echo "To rollback a deployment:"
echo "  GitHub → Actions → Rollback Deployment → Run workflow"
echo ""
echo "For more details, see CI-CD-GUIDE.md"
echo ""
