# GitHub Actions CI/CD Pipeline for Kubernetes Weather App

Production-grade CI/CD automation using GitHub Actions with dry-run validation, automated testing, security scanning, and deployment.

## 🚀 Quick Start

### 1. Copy Files to Your Repository

```bash
# Copy these files to your k8s-weather-app repository:
cp -r .github /path/to/k8s-weather-app/
cp .yamllint.yml /path/to/k8s-weather-app/
cp CI-CD-GUIDE.md /path/to/k8s-weather-app/
```

### 2. Configure GitHub Secrets

Go to: **Your Repo → Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name | Value | Where to Get |
|-------------|-------|--------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | https://hub.docker.com |
| `DOCKERHUB_TOKEN` | Docker Hub access token | Hub → Settings → Security → New Access Token |
| `OPENWEATHER_API_KEY` | OpenWeatherMap API key | https://openweathermap.org/api |

### 3. Push to GitHub

```bash
cd /path/to/k8s-weather-app
git add .
git commit -m "Add CI/CD pipeline"
git push origin main
```

### 4. Watch Pipeline Run

Go to: **Your Repo → Actions tab**

You'll see the CI/CD pipeline running automatically!

---

## 📦 What's Included

### Workflows

1. **ci-cd.yml** - Main CI/CD pipeline
   - Lint & validate code
   - Build Docker images
   - Security scanning
   - Dry-run validation
   - Deploy to Minikube

2. **pr-validation.yml** - Pull request validation
   - Code quality checks
   - Security scans
   - Build verification

3. **manual-deploy.yml** - Manual deployment
   - Deploy specific versions
   - Dry-run mode
   - Environment selection

4. **rollback.yml** - Quick rollback
   - Rollback to previous version
   - Service selection

### Configuration Files

- **.yamllint.yml** - YAML linting rules
- **CI-CD-GUIDE.md** - Complete documentation

---

## 🎯 Features

✅ **Automated Testing** - Lint, validate, and test on every push  
✅ **Docker Build & Push** - Multi-stage builds with layer caching  
✅ **Security Scanning** - Trivy vulnerability scanning  
✅ **Dry Run Validation** - Test deployments safely  
✅ **Automated Deployment** - Deploy to Minikube automatically  
✅ **Manual Deployment** - Deploy specific versions on demand  
✅ **Rollback Support** - Quick rollback to stable versions  
✅ **Multi-Environment** - Development, staging, production  

---

## 📖 Documentation

See **CI-CD-GUIDE.md** for complete documentation including:

- Detailed workflow explanations
- How to use dry-run mode
- Troubleshooting guide
- Best practices
- Examples

---

## 🔄 Workflow Triggers

### Automatic Triggers

- **Push to main/develop** → Full CI/CD pipeline runs
- **Pull Request** → PR validation runs
- **Any push** → Lint and build verification

### Manual Triggers

- **Manual Deploy** → GitHub → Actions → Manual Deploy → Run workflow
- **Rollback** → GitHub → Actions → Rollback Deployment → Run workflow

---

## 🧪 Testing the Pipeline

### Option 1: Make a Code Change

```bash
# Edit any file
echo "# Test" >> city-service/app.py

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push origin main

# Watch in GitHub Actions tab
```

### Option 2: Manual Trigger

1. Go to **GitHub → Actions → Manual Deploy**
2. Click **"Run workflow"**
3. Select options and run

---

## 🎓 CI/CD Pipeline Flow

```
┌─────────────┐
│ Code Push   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Lint      │  ← Check code quality
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Build     │  ← Build Docker images
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Security   │  ← Scan for vulnerabilities
│   Scan      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Dry Run    │  ← Validate deployment
│ (No Apply)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Push Images │  ← Push to Docker Hub
│ to Registry │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Deploy    │  ← Deploy to Minikube
│ to Cluster  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Notify    │  ← Report status
└─────────────┘
```

---

## 🔐 Security

- **Secrets Management** - All sensitive data in GitHub Secrets
- **Image Scanning** - Trivy scans for vulnerabilities
- **Dependency Checks** - Safety checks Python packages
- **Secret Detection** - Scans for hardcoded secrets in code
- **Least Privilege** - Docker containers run as non-root

---

## 🐛 Troubleshooting

### Pipeline Fails on Lint

**Fix**: Run linter locally first
```bash
pip install flake8 black
flake8 city-service/app.py --max-line-length=120
black city-service/app.py
```

### Image Push Fails

**Fix**: Check Docker Hub secrets
```bash
# Verify DOCKERHUB_USERNAME and DOCKERHUB_TOKEN in GitHub Secrets
# Make sure token has Write permissions
```

### Deployment Timeout

**Fix**: Check resource limits
```yaml
# In deployment YAML
resources:
  limits:
    memory: "512Mi"  # Increase if needed
```

---

## 📚 Learn More

- **CI-CD-GUIDE.md** - Complete documentation
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Docker Build Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

## 🎉 You're Ready!

Your repository now has enterprise-grade CI/CD automation!

**Next Steps:**
1. Read CI-CD-GUIDE.md
2. Configure GitHub Secrets
3. Make a commit to test the pipeline
4. Monitor deployment in Actions tab

Happy Deploying! 🚀
