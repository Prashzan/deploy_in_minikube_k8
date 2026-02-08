# CI/CD Pipeline Documentation

Complete GitHub Actions CI/CD pipeline for Weather Microservices on Kubernetes.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Workflows](#workflows)
- [Setup Instructions](#setup-instructions)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [How to Use](#how-to-use)
- [Pipeline Stages](#pipeline-stages)
- [Dry Run Explained](#dry-run-explained)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This CI/CD pipeline provides:

✅ **Automated Testing** - Lint code, validate manifests  
✅ **Docker Build** - Multi-stage builds with caching  
✅ **Security Scanning** - Vulnerability detection with Trivy  
✅ **Dry Run Validation** - Test deployments without applying  
✅ **Automated Deployment** - Deploy to Minikube on merge to main  
✅ **Manual Deployment** - Deploy specific versions to any environment  
✅ **Rollback Support** - Quick rollback to previous versions  

---

## 🔄 Workflows

### 1. **Main CI/CD Pipeline** (`ci-cd.yml`)

**Triggers**: 
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual trigger

**Jobs**:
1. **Lint and Validate** - Check code quality and K8s manifests
2. **Build and Test** - Build Docker images and run tests
3. **Dry Run** - Validate Kubernetes deployment (no actual deployment)
4. **Build and Push** - Push images to Docker Hub (only on main branch)
5. **Deploy to Minikube** - Deploy to staging environment
6. **Notify** - Send deployment status notification

**Workflow**:
```
Code Push → Lint → Build → Dry Run → Push to Registry → Deploy → Notify
```

### 2. **Pull Request Validation** (`pr-validation.yml`)

**Triggers**: Pull requests to `main` or `develop`

**Jobs**:
- Validate code changes
- Lint Python and YAML files
- Build Docker images (no push)
- Security scan
- Check for hardcoded secrets

### 3. **Manual Deployment** (`manual-deploy.yml`)

**Triggers**: Manual trigger via GitHub UI

**Inputs**:
- **Environment**: development, staging, production
- **Version**: Docker image tag to deploy
- **Dry Run**: Test deployment without applying

**Use Cases**:
- Deploy specific version to any environment
- Test deployment with dry-run mode
- Hotfix deployments

### 4. **Rollback** (`rollback.yml`)

**Triggers**: Manual trigger via GitHub UI

**Inputs**:
- **Service**: Which service to rollback (all, city-service, weather-service, frontend)
- **Revision**: Specific revision number (optional)

**Use Cases**:
- Quick rollback after failed deployment
- Rollback to specific previous version

---

## 🚀 Setup Instructions

### Step 1: Fork/Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/k8s-weather-app.git
cd k8s-weather-app
```

### Step 2: Create GitHub Repository

```bash
# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit with CI/CD pipeline"

# Create repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/k8s-weather-app.git
git push -u origin main
```

### Step 3: Copy Workflow Files

Copy these files to your repository:

```
.github/
└── workflows/
    ├── ci-cd.yml
    ├── pr-validation.yml
    ├── manual-deploy.yml
    └── rollback.yml
.yamllint.yml
```

```bash
# Copy CI/CD files from this package
cp -r .github /path/to/your/repo/
cp .yamllint.yml /path/to/your/repo/
```

---

## 🔐 GitHub Secrets Configuration

Go to: **GitHub Repository → Settings → Secrets and variables → Actions**

Click **"New repository secret"** and add these:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | `johndoe` |
| `DOCKERHUB_TOKEN` | Docker Hub access token | `dckr_pat_xxxxx...` |
| `OPENWEATHER_API_KEY` | OpenWeatherMap API key | `abc123xyz789...` |

### How to Get Docker Hub Token:

1. Go to https://hub.docker.com/
2. Click **Account Settings** → **Security**
3. Click **New Access Token**
4. Name: `github-actions`
5. Permissions: **Read, Write, Delete**
6. Copy the token (you won't see it again!)
7. Add to GitHub Secrets as `DOCKERHUB_TOKEN`

### How to Get OpenWeatherMap API Key:

1. Go to https://openweathermap.org/api
2. Sign up for free account
3. Verify email
4. Go to **API keys** section
5. Copy your API key
6. Add to GitHub Secrets as `OPENWEATHER_API_KEY`

---

## 📖 How to Use

### Scenario 1: Normal Development Flow

```bash
# 1. Create feature branch
git checkout -b feature/add-new-city-endpoint

# 2. Make changes
vim city-service/app.py

# 3. Commit and push
git add .
git commit -m "Add new city endpoint"
git push origin feature/add-new-city-endpoint

# 4. Create Pull Request on GitHub
# → PR Validation workflow runs automatically
# → Shows lint results, build status, security scan

# 5. After review, merge to main
# → Main CI/CD pipeline runs
# → Builds images
# → Runs dry-run validation
# → Pushes to Docker Hub
# → Deploys to Minikube
```

### Scenario 2: Manual Deployment

1. Go to **GitHub → Actions → Manual Deploy**
2. Click **"Run workflow"**
3. Select:
   - Environment: `staging`
   - Version: `latest` or specific SHA
   - Dry Run: `false`
4. Click **"Run workflow"**
5. Monitor deployment in Actions tab

### Scenario 3: Dry Run Before Deployment

1. Go to **GitHub → Actions → Manual Deploy**
2. Click **"Run workflow"**
3. Select:
   - Environment: `production`
   - Version: `abc123def` (commit SHA)
   - Dry Run: `true` ← **Enable dry run**
4. Click **"Run workflow"**
5. Check results - no actual deployment happens
6. If successful, run again with Dry Run: `false`

### Scenario 4: Rollback After Failed Deployment

1. Go to **GitHub → Actions → Rollback Deployment**
2. Click **"Run workflow"**
3. Select:
   - Service: `all` (or specific service)
   - Revision: `` (leave empty for previous version)
4. Click **"Run workflow"**
5. Services roll back to previous stable version

---

## 🔍 Pipeline Stages Explained

### Stage 1: Lint and Validate

**What it does**:
- Checks Python code style with `flake8` and `black`
- Validates Kubernetes YAML syntax with `kubeval`
- Checks YAML formatting with `yamllint`

**Why it's important**:
- Catches syntax errors early
- Ensures consistent code style
- Prevents invalid K8s manifests

**Example output**:
```
✓ city-service/app.py: No style issues found
✓ k8s/06-city-service-deployment.yaml: Valid
```

### Stage 2: Build and Test

**What it does**:
- Builds Docker images with BuildKit
- Uses layer caching for faster builds
- Tests if containers run successfully
- Scans for security vulnerabilities

**Why it's important**:
- Ensures images build correctly
- Catches runtime errors
- Identifies security issues

**Example output**:
```
Building city-service...
✓ Image built: city-service:test
✓ Container starts successfully
✓ Security scan: 0 critical vulnerabilities
```

### Stage 3: Dry Run

**What it does**:
- Prepares K8s manifests with correct image tags
- Runs `kubectl apply --dry-run=client`
- Validates manifests without applying
- Uploads manifests as artifacts

**Why it's important**:
- Tests deployment before actually deploying
- Catches configuration errors
- No impact on running cluster

**Example output**:
```
Running Kubernetes dry-run validation...
namespace/weather-app configured (dry run)
deployment.apps/city-service configured (dry run)
✓ Dry run validation passed
```

### Stage 4: Build and Push

**What it does**:
- Builds production Docker images
- Tags with commit SHA + `latest`
- Pushes to Docker Hub
- Uses cache for efficiency

**Why it's important**:
- Makes images available for deployment
- Versioning with SHA enables rollback
- `latest` tag for convenience

**Example output**:
```
Pushing prashzan/city-service:abc123def...
Pushing prashzan/city-service:latest...
✓ Images pushed successfully
```

### Stage 5: Deploy to Minikube

**What it does**:
- Starts Minikube cluster
- Applies all K8s manifests in correct order
- Waits for pods to be ready
- Runs smoke tests

**Why it's important**:
- Automated deployment to staging
- Validates full deployment flow
- Catches integration issues

**Example output**:
```
Deploying to Minikube...
✓ PostgreSQL ready
✓ City Service ready (2/2 pods)
✓ Weather Service ready (2/2 pods)
✓ Frontend ready (2/2 pods)
✓ Smoke tests passed
```

### Stage 6: Notify

**What it does**:
- Checks deployment status
- Logs success or failure
- Could send Slack/email notifications (optional)

**Example output**:
```
🎉 Deployment successful!
Version: abc123def456
Deployed at: 2024-02-07 14:30:25
```

---

## 🧪 Dry Run Explained

### What is Dry Run?

Dry run simulates a deployment without actually applying changes to the cluster.

```bash
# Normal deployment
kubectl apply -f deployment.yaml
# ↑ Actually creates/updates resources

# Dry run
kubectl apply --dry-run=client -f deployment.yaml
# ↑ Only validates, doesn't create anything
```

### Why Use Dry Run?

✅ **Safe Testing** - Test changes without risk  
✅ **Validation** - Catch errors before deployment  
✅ **Preview** - See what would change  
✅ **CI/CD** - Validate in pipeline before merge  

### Dry Run Types

**Client-side** (`--dry-run=client`):
- Validates YAML syntax
- Checks required fields
- No server interaction
- Fast

**Server-side** (`--dry-run=server`):
- Full validation including admission controllers
- Requires cluster access
- More thorough

### When to Use Dry Run

| Scenario | Use Dry Run? |
|----------|-------------|
| Testing new manifests | ✅ Yes |
| Updating image tags | ✅ Yes |
| Production deployment | ✅ Yes (first) |
| Development deployment | Optional |
| Rollback | ❌ No (use undo) |

### Example Workflow with Dry Run

```bash
# 1. Test with dry run
./manual-deploy.sh --dry-run

# 2. Review output
✓ All manifests valid
✓ No conflicts detected

# 3. Deploy for real
./manual-deploy.sh

# 4. Verify
kubectl get pods
```

---

## 🐛 Troubleshooting

### Issue 1: Docker Hub Push Failed

**Error**: `denied: requested access to the resource is denied`

**Solution**:
```bash
# Check GitHub secrets
GitHub → Settings → Secrets → Actions
Verify: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN

# Verify Docker Hub token has Write permissions
Docker Hub → Account Settings → Security → Access Tokens
```

### Issue 2: Image Pull Error in Deployment

**Error**: `ImagePullBackOff`

**Solution**:
```bash
# Check if images are public on Docker Hub
Docker Hub → Repositories → city-service → Settings
Make sure "Public" is selected

# Or add image pull secret to K8s
kubectl create secret docker-registry dockerhub \
  --docker-username=your-username \
  --docker-password=your-token \
  -n weather-app
```

### Issue 3: Dry Run Validation Fails

**Error**: `error validating data: ValidationError`

**Solution**:
```bash
# Check manifest locally
kubectl apply --dry-run=client -f k8s/06-city-service-deployment.yaml

# Common issues:
# - Incorrect indentation
# - Missing required fields
# - Invalid resource names
# - Typo in kind/apiVersion
```

### Issue 4: Deployment Timeout

**Error**: `timed out waiting for the condition`

**Solution**:
```bash
# Check pod status
kubectl get pods -n weather-app

# Check pod logs
kubectl logs <pod-name> -n weather-app

# Check pod events
kubectl describe pod <pod-name> -n weather-app

# Common causes:
# - Image pull errors
# - Health check failures
# - Resource limits too low
# - Missing secrets/configmaps
```

### Issue 5: Smoke Tests Fail

**Error**: `curl: (7) Failed to connect`

**Solution**:
```bash
# Check if services are ready
kubectl get svc -n weather-app

# Check if pods are running
kubectl get pods -n weather-app

# Test manually
kubectl port-forward -n weather-app service/city-service 5001:5001
curl http://localhost:5001/health
```

---

## 📊 Monitoring Pipeline Status

### GitHub Actions UI

1. Go to **GitHub → Actions** tab
2. See all workflow runs
3. Click on a run to see details
4. Expand jobs to see logs

### Status Badges

Add to README.md:

```markdown
![CI/CD Pipeline](https://github.com/YOUR_USERNAME/k8s-weather-app/actions/workflows/ci-cd.yml/badge.svg)
```

### Email Notifications

GitHub automatically sends emails for:
- Failed workflows
- Successful deployments (if enabled)

---

## 🎯 Best Practices

### 1. Always Use Dry Run for Production

```yaml
# In manual-deploy.yml
# First run with dry_run: true
# Then run with dry_run: false
```

### 2. Tag Images with SHA

```bash
# Good (traceable)
image: prashzan/city-service:abc123def

# Bad (not traceable)
image: prashzan/city-service:latest
```

### 3. Test in Staging First

```
Develop → PR → Merge → Deploy to Staging → Test → Deploy to Production
```

### 4. Keep Secrets Secure

```bash
# Never commit:
✗ API keys in code
✗ Passwords in YAML
✗ Tokens in scripts

# Always use:
✓ GitHub Secrets
✓ Kubernetes Secrets
✓ Environment variables
```

### 5. Monitor Deployments

```bash
# Watch deployment progress
kubectl rollout status deployment/city-service -n weather-app

# Check logs
kubectl logs -f deployment/city-service -n weather-app

# View metrics
kubectl top pods -n weather-app
```

---

## 🚀 Next Steps

### Add More Workflows

1. **Scheduled Tests** - Run tests nightly
2. **Performance Tests** - Load testing
3. **Database Backups** - Automated backups
4. **Slack Notifications** - Deploy notifications

### Improve Security

1. **Container Scanning** - Scan for CVEs
2. **SAST** - Static code analysis
3. **Secret Scanning** - Detect leaked secrets
4. **Dependency Updates** - Dependabot

### Add Environments

1. **Development** - Feature testing
2. **Staging** - Pre-production
3. **Production** - Live environment

---

## 📚 Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Happy CI/CD! 🎉**

