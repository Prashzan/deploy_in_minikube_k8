# Quick Start Guide - Weather App on Kubernetes

Get the app running on Minikube in **5 minutes**!

## Prerequisites Check

```bash
# Check Docker
docker --version
# Should show: Docker version 20.10+

# Check Minikube
minikube version
# Should show: minikube version v1.25+

# Check kubectl
kubectl version --client
# Should show: Client Version v1.25+
```

**Don't have these?** See [Installation Guide](#installation-guide) below.

---

## 5-Step Deployment

### Step 1: Start Minikube (30 seconds)

```bash
minikube start --cpus=4 --memory=4096
```

### Step 2: Set Your Docker Hub Username (10 seconds)

```bash
export DOCKERHUB_USERNAME=your_username_here
```

### Step 3: Build & Push Images (5 minutes)

```bash
./build-and-push.sh
# Enter Docker Hub credentials when prompted
```

### Step 4: Configure Kubernetes (30 seconds)

```bash
# Update image references
./update-k8s-images.sh $DOCKERHUB_USERNAME

# Edit k8s/02-secrets.yaml and add your OpenWeatherMap API key
# Change this line:
#   openweather-api-key: "your_openweather_api_key_here"
```

Get free API key: https://openweathermap.org/api

### Step 5: Deploy! (2 minutes)

```bash
./deploy.sh
```

---

## Access Your App

```bash
# Open frontend in browser
minikube service frontend-service -n weather-app
```

**That's it!** 🎉

---

## What Just Happened?

1. **Minikube started** - Local Kubernetes cluster running
2. **Docker images built** - 3 microservices containerized
3. **Images pushed to Docker Hub** - Available for Kubernetes
4. **Deployed to Kubernetes**:
   - PostgreSQL database (1 pod)
   - City Service (2 pods)
   - Weather Service (2 pods)
   - Frontend (2 pods)
5. **Services exposed** - Accessible via Minikube

---

## Quick Commands

### View Everything

```bash
# All pods
kubectl get pods -n weather-app

# All services
kubectl get svc -n weather-app

# Everything
kubectl get all -n weather-app
```

### Test APIs

```bash
# Get service URLs
CITY=$(minikube service city-service -n weather-app --url)
WEATHER=$(minikube service weather-service -n weather-app --url)

# Test
curl $CITY/health
curl "$WEATHER/api/weather?city=London"
```

### View Logs

```bash
# Weather service logs
kubectl logs -f deployment/weather-service -n weather-app

# Database logs
kubectl logs -f deployment/postgres -n weather-app
```

### Test Database

```bash
./test-database.sh
# Choose option 3 to view recent searches
```

---

## Troubleshooting

### Pods not starting?

```bash
# Check status
kubectl get pods -n weather-app

# View details
kubectl describe pod <pod-name> -n weather-app

# View logs
kubectl logs <pod-name> -n weather-app
```

### Can't access frontend?

```bash
# Try port forwarding
kubectl port-forward -n weather-app service/frontend-service 8080:80
# Access at: http://localhost:8080
```

### API returns 401 error?

Your API key is wrong or missing. Edit `k8s/02-secrets.yaml` with correct key, then:

```bash
kubectl delete secret weather-app-secrets -n weather-app
kubectl apply -f k8s/02-secrets.yaml
kubectl rollout restart deployment/weather-service -n weather-app
kubectl rollout restart deployment/city-service -n weather-app
```

---

## Clean Up

```bash
# Delete everything
kubectl delete namespace weather-app

# Stop Minikube
minikube stop

# Or delete Minikube completely
minikube delete
```

---

## Installation Guide

### Install Docker

**Mac**:
```bash
brew install --cask docker
```
Or download from: https://docs.docker.com/desktop/mac/install/

**Linux**:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Windows**:
Download from: https://docs.docker.com/desktop/windows/install/

### Install Minikube

**Mac**:
```bash
brew install minikube
```

**Linux**:
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

**Windows**:
```powershell
choco install minikube
```

Or download from: https://minikube.sigs.k8s.io/docs/start/

### Install kubectl

**Mac**:
```bash
brew install kubectl
```

**Linux**:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Windows**:
```powershell
choco install kubernetes-cli
```

Or download from: https://kubernetes.io/docs/tasks/tools/

---

## Next Steps

- Read the full [README.md](README.md) for detailed explanations
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for design details
- Try scaling: `kubectl scale deployment weather-service --replicas=5 -n weather-app`
- Add monitoring with Prometheus
- Deploy to cloud (GKE, EKS, AKS)

---

**Happy Kubernetes Learning!** 🚀
