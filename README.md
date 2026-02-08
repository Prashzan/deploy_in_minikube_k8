# Weather Microservices on Kubernetes

A complete production-ready microservices application deployed on Kubernetes (Minikube), featuring 4 services: City Service, Weather Service, Frontend (Nginx), and PostgreSQL database.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start Guide](#quick-start-guide)
- [Detailed Setup Instructions](#detailed-setup-instructions)
- [Kubernetes Concepts Explained](#kubernetes-concepts-explained)
- [Docker Hub Setup](#docker-hub-setup)
- [Database Operations](#database-operations)
- [Testing the Deployment](#testing-the-deployment)
- [Troubleshooting](#troubleshooting)
- [Scaling and Management](#scaling-and-management)
- [Cleanup](#cleanup)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                       │
│                      (Minikube)                             │
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │           Namespace: weather-app                   │   │
│  │                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐               │   │
│  │  │   Frontend   │  │   Frontend   │               │   │
│  │  │  (Pod 1/2)   │  │  (Pod 2/2)   │               │   │
│  │  │  Nginx:80    │  │  Nginx:80    │               │   │
│  │  └──────┬───────┘  └──────┬───────┘               │   │
│  │         │                 │                        │   │
│  │         └────────┬────────┘                        │   │
│  │                  │                                 │   │
│  │         ┌────────▼────────┐                        │   │
│  │         │ frontend-service│ (NodePort: 30080)     │   │
│  │         │   LoadBalancer  │                        │   │
│  │         └─────────────────┘                        │   │
│  │                  │                                 │   │
│  │         ┌────────┴────────┐                        │   │
│  │         │                 │                        │   │
│  │         ▼                 ▼                        │   │
│  │  ┌──────────────┐  ┌──────────────┐               │   │
│  │  │City Service  │  │City Service  │               │   │
│  │  │  (Pod 1/2)   │  │  (Pod 2/2)   │               │   │
│  │  │  Flask:5001  │  │  Flask:5001  │               │   │
│  │  └──────────────┘  └──────────────┘               │   │
│  │         │                                          │   │
│  │  ┌──────▼──────────┐                              │   │
│  │  │  city-service   │ (NodePort: 30001)            │   │
│  │  └─────────────────┘                              │   │
│  │                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐               │   │
│  │  │Weather Svc   │  │Weather Svc   │               │   │
│  │  │  (Pod 1/2)   │  │  (Pod 2/2)   │               │   │
│  │  │  Flask:5002  │  │  Flask:5002  │               │   │
│  │  └──────┬───────┘  └──────┬───────┘               │   │
│  │         │                 │                        │   │
│  │         └────────┬────────┘                        │   │
│  │                  │                                 │   │
│  │         ┌────────▼────────┐                        │   │
│  │         │ weather-service │ (NodePort: 30002)     │   │
│  │         └────────┬────────┘                        │   │
│  │                  │                                 │   │
│  │                  ▼                                 │   │
│  │         ┌──────────────────┐                       │   │
│  │         │   PostgreSQL     │                       │   │
│  │         │   (StatefulSet)  │                       │   │
│  │         │   Port: 5432     │                       │   │
│  │         └────────┬─────────┘                       │   │
│  │                  │                                 │   │
│  │         ┌────────▼────────┐                        │   │
│  │         │postgres-service │ (ClusterIP)            │   │
│  │         └─────────────────┘                        │   │
│  │                  │                                 │   │
│  │         ┌────────▼────────┐                        │   │
│  │         │PersistentVolume │                        │   │
│  │         │  (1Gi Storage)  │                        │   │
│  │         └─────────────────┘                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

External Access (via Minikube):
  - Frontend:        minikube service frontend-service -n weather-app
  - City Service:    minikube service city-service -n weather-app
  - Weather Service: minikube service weather-service -n weather-app
```

### Service Communication:

1. **User → Frontend** (via NodePort 30080)
2. **Frontend → City Service** (via Service DNS: `city-service.weather-app.svc.cluster.local:5001`)
3. **Frontend → Weather Service** (via Service DNS: `weather-service.weather-app.svc.cluster.local:5002`)
4. **Weather Service → PostgreSQL** (via Service DNS: `postgres-service.weather-app.svc.cluster.local:5432`)
5. **Services → External API** (OpenWeatherMap API)

---

## 📦 Prerequisites

### Required Software:

1. **Docker** (version 20.10+)
   ```bash
   docker --version
   ```

2. **Minikube** (version 1.25+)
   ```bash
   minikube version
   ```
   Install: https://minikube.sigs.k8s.io/docs/start/

3. **kubectl** (version 1.25+)
   ```bash
   kubectl version --client
   ```
   Install: https://kubernetes.io/docs/tasks/tools/

4. **Docker Hub Account**
   - Sign up at: https://hub.docker.com/
   - Free tier is sufficient

5. **OpenWeatherMap API Key**
   - Sign up at: https://openweathermap.org/api
   - Free tier: 1000 calls/day
   - Verify email and get API key

---

## 📁 Project Structure

```
k8s-weather-app/
├── city-service/
│   ├── app.py                    # City service application
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile                # Multi-stage Docker build
├── weather-service/
│   ├── app.py                    # Weather service application
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile                # Multi-stage Docker build
├── frontend/
│   ├── index.html                # Frontend UI
│   ├── nginx.conf                # Nginx configuration
│   └── Dockerfile                # Nginx Docker build
├── k8s/
│   ├── 00-namespace.yaml         # Namespace definition
│   ├── 01-configmap.yaml         # ConfigMap for DB init
│   ├── 02-secrets.yaml           # Secrets for API key and DB credentials
│   ├── 03-pvc.yaml               # PersistentVolumeClaim for PostgreSQL
│   ├── 04-postgres-deployment.yaml
│   ├── 05-postgres-service.yaml
│   ├── 06-city-service-deployment.yaml
│   ├── 07-city-service-service.yaml
│   ├── 08-weather-service-deployment.yaml
│   ├── 09-weather-service-service.yaml
│   ├── 10-frontend-deployment.yaml
│   └── 11-frontend-service.yaml
├── build-and-push.sh             # Build and push Docker images
├── update-k8s-images.sh          # Update K8s manifests with your username
├── deploy.sh                     # Deploy to Kubernetes
├── test-k8s.sh                   # Test deployment
├── test-database.sh              # Database testing script
└── README.md                     # This file
```

---

## 🚀 Quick Start Guide

### Step 1: Start Minikube

```bash
minikube start --cpus=4 --memory=4096
```

### Step 2: Set Up Docker Hub

```bash
# Replace with your Docker Hub username
export DOCKERHUB_USERNAME=your_dockerhub_username
```

### Step 3: Build and Push Images

```bash
./build-and-push.sh
# This will:
# 1. Login to Docker Hub
# 2. Build all 3 images
# 3. Push to Docker Hub
```

### Step 4: Update Kubernetes Manifests

```bash
./update-k8s-images.sh $DOCKERHUB_USERNAME
```

### Step 5: Update API Key

Edit `k8s/02-secrets.yaml`:
```yaml
openweather-api-key: "paste_your_actual_api_key_here"
```

### Step 6: Deploy to Kubernetes

```bash
./deploy.sh
```

### Step 7: Access the Application

```bash
# Open frontend in browser
minikube service frontend-service -n weather-app
```

**That's it!** Your application is now running on Kubernetes! 🎉

---

## 📖 Detailed Setup Instructions

### Part 1: Docker Hub Setup

#### 1.1 Create Docker Hub Account

1. Go to https://hub.docker.com/
2. Sign up for free account
3. Verify your email
4. Remember your username

#### 1.2 Login to Docker Hub

```bash
docker login
# Enter username and password
```

### Part 2: Build Docker Images

#### 2.1 Automated Build (Recommended)

```bash
# Set your Docker Hub username
export DOCKERHUB_USERNAME=johndoe  # Replace with your username

# Run build script
./build-and-push.sh
```

This script will:
- Build all 3 Docker images
- Tag them with your Docker Hub username
- Push them to Docker Hub

#### 2.2 Manual Build (Alternative)

```bash
# Build city-service
cd city-service
docker build -t $DOCKERHUB_USERNAME/city-service:v1.0 .
docker push $DOCKERHUB_USERNAME/city-service:v1.0
cd ..

# Build weather-service
cd weather-service
docker build -t $DOCKERHUB_USERNAME/weather-service:v1.0 .
docker push $DOCKERHUB_USERNAME/weather-service:v1.0
cd ..

# Build frontend
cd frontend
docker build -t $DOCKERHUB_USERNAME/weather-frontend:v1.0 .
docker push $DOCKERHUB_USERNAME/weather-frontend:v1.0
cd ..
```

#### 2.3 Verify Images on Docker Hub

Go to https://hub.docker.com/ and check your repositories.

You should see:
- `your_username/city-service:v1.0`
- `your_username/weather-service:v1.0`
- `your_username/weather-frontend:v1.0`

### Part 3: Configure Kubernetes Manifests

#### 3.1 Update Image References

```bash
./update-k8s-images.sh $DOCKERHUB_USERNAME
```

This updates these files:
- `k8s/06-city-service-deployment.yaml`
- `k8s/08-weather-service-deployment.yaml`
- `k8s/10-frontend-deployment.yaml`

#### 3.2 Update API Key

Edit `k8s/02-secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: weather-app-secrets
  namespace: weather-app
type: Opaque
stringData:
  openweather-api-key: "your_actual_api_key_here"  # ← REPLACE THIS
  postgres-password: "weatherpass"
  postgres-user: "weatheruser"
  postgres-db: "weatherdb"
```

**Get your API key from:** https://openweathermap.org/api

### Part 4: Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=4096 --driver=docker

# Verify Minikube is running
minikube status
```

Expected output:
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

### Part 5: Deploy to Kubernetes

#### 5.1 Automated Deployment (Recommended)

```bash
./deploy.sh
```

This script:
1. Creates namespace
2. Creates ConfigMaps and Secrets
3. Creates PersistentVolumeClaim
4. Deploys PostgreSQL
5. Waits for PostgreSQL to be ready
6. Deploys City Service
7. Deploys Weather Service
8. Deploys Frontend
9. Shows deployment status

#### 5.2 Manual Deployment (Step-by-Step)

```bash
# 1. Create namespace
kubectl apply -f k8s/00-namespace.yaml

# 2. Create ConfigMap
kubectl apply -f k8s/01-configmap.yaml

# 3. Create Secrets
kubectl apply -f k8s/02-secrets.yaml

# 4. Create PVC
kubectl apply -f k8s/03-pvc.yaml

# 5. Deploy PostgreSQL
kubectl apply -f k8s/04-postgres-deployment.yaml
kubectl apply -f k8s/05-postgres-service.yaml

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod -l app=postgres -n weather-app --timeout=120s

# 6. Deploy City Service
kubectl apply -f k8s/06-city-service-deployment.yaml
kubectl apply -f k8s/07-city-service-service.yaml

# 7. Deploy Weather Service
kubectl apply -f k8s/08-weather-service-deployment.yaml
kubectl apply -f k8s/09-weather-service-service.yaml

# 8. Deploy Frontend
kubectl apply -f k8s/10-frontend-deployment.yaml
kubectl apply -f k8s/11-frontend-service.yaml
```

### Part 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n weather-app

# Check services
kubectl get svc -n weather-app

# Check persistent volumes
kubectl get pvc -n weather-app
```

Expected pod output:
```
NAME                               READY   STATUS    RESTARTS   AGE
city-service-xxxxxxxxx-xxxxx       1/1     Running   0          2m
city-service-xxxxxxxxx-xxxxx       1/1     Running   0          2m
weather-service-xxxxxxxxx-xxxxx    1/1     Running   0          2m
weather-service-xxxxxxxxx-xxxxx    1/1     Running   0          2m
frontend-xxxxxxxxx-xxxxx           1/1     Running   0          2m
frontend-xxxxxxxxx-xxxxx           1/1     Running   0          2m
postgres-xxxxxxxxx-xxxxx           1/1     Running   0          3m
```

---

## 🌐 Accessing the Application

### Method 1: Using Minikube Service Command (Easiest)

```bash
# Open frontend in browser
minikube service frontend-service -n weather-app

# Get URL without opening browser
minikube service frontend-service -n weather-app --url
```

### Method 2: Using NodePort

```bash
# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Access services
echo "Frontend: http://$MINIKUBE_IP:30080"
echo "City Service: http://$MINIKUBE_IP:30001"
echo "Weather Service: http://$MINIKUBE_IP:30002"
```

### Method 3: Port Forwarding

```bash
# Forward frontend to localhost:8080
kubectl port-forward -n weather-app service/frontend-service 8080:80

# Access at: http://localhost:8080
```

---

## 🎓 Kubernetes Concepts Explained

### 1. Namespace

**What**: Logical isolation within a cluster  
**Why**: Organize resources, apply policies, avoid naming conflicts  
**File**: `00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: weather-app
```

**Commands**:
```bash
# List namespaces
kubectl get namespaces

# View resources in namespace
kubectl get all -n weather-app
```

### 2. ConfigMap

**What**: Store non-sensitive configuration data  
**Why**: Separate config from container images  
**File**: `01-configmap.yaml`

Our ConfigMap stores the database initialization SQL script.

**Commands**:
```bash
# View ConfigMap
kubectl get configmap -n weather-app
kubectl describe configmap postgres-init-script -n weather-app
```

### 3. Secrets

**What**: Store sensitive data (passwords, API keys)  
**Why**: Security - keeps secrets out of code  
**File**: `02-secrets.yaml`

Our Secrets store:
- OpenWeatherMap API key
- PostgreSQL credentials

**Commands**:
```bash
# View Secrets (values are base64 encoded)
kubectl get secrets -n weather-app
kubectl describe secret weather-app-secrets -n weather-app

# Decode a secret
kubectl get secret weather-app-secrets -n weather-app -o jsonpath='{.data.openweather-api-key}' | base64 --decode
```

### 4. PersistentVolumeClaim (PVC)

**What**: Request for storage  
**Why**: Data persistence (survives pod restarts)  
**File**: `03-pvc.yaml`

```yaml
spec:
  accessModes:
    - ReadWriteOnce  # One pod can mount at a time
  resources:
    requests:
      storage: 1Gi
```

**Commands**:
```bash
# View PVC
kubectl get pvc -n weather-app

# View PV (auto-created by Minikube)
kubectl get pv
```

### 5. Deployment

**What**: Manages replica sets and pods  
**Why**: Declarative updates, scaling, rollback  
**Files**: `04, 06, 08, 10-*-deployment.yaml`

Key features:
- **Replicas**: Number of pod copies
- **Rolling updates**: Zero-downtime deployments
- **Health checks**: Liveness and readiness probes

**Commands**:
```bash
# View deployments
kubectl get deployments -n weather-app

# Scale a deployment
kubectl scale deployment weather-service --replicas=3 -n weather-app

# View deployment details
kubectl describe deployment weather-service -n weather-app

# View rollout status
kubectl rollout status deployment/weather-service -n weather-app
```

### 6. Service

**What**: Stable network endpoint for pods  
**Why**: Load balancing, service discovery  
**Files**: `05, 07, 09, 11-*-service.yaml`

**Service Types**:

1. **ClusterIP** (postgres-service):
   - Internal only
   - Not accessible from outside cluster
   - Used for database

2. **NodePort** (city-service, weather-service, frontend-service):
   - Exposes service on each node's IP
   - Accessible from outside cluster
   - Port range: 30000-32767

**Commands**:
```bash
# View services
kubectl get svc -n weather-app

# Get service endpoints
kubectl get endpoints -n weather-app

# Describe service
kubectl describe svc frontend-service -n weather-app
```

### 7. Health Probes

**Liveness Probe**: Is the container alive?  
**Readiness Probe**: Is the container ready to serve traffic?

**Example from weather-service**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5002
  initialDelaySeconds: 60
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 5002
  initialDelaySeconds: 30
  periodSeconds: 5
```

**Commands**:
```bash
# View pod events (shows probe failures)
kubectl describe pod <pod-name> -n weather-app
```

---

## 🐳 Docker Hub Setup

### Where to Add Your Docker Hub Repository

You need to update **3 files** with your Docker Hub username:

#### Option 1: Automated (Recommended)

```bash
./update-k8s-images.sh your_dockerhub_username
```

#### Option 2: Manual

Edit these files:

**1. k8s/06-city-service-deployment.yaml**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: city-service
        image: YOUR_DOCKERHUB_USERNAME/city-service:v1.0  # ← CHANGE THIS
```

**2. k8s/08-weather-service-deployment.yaml**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: weather-service
        image: YOUR_DOCKERHUB_USERNAME/weather-service:v1.0  # ← CHANGE THIS
```

**3. k8s/10-frontend-deployment.yaml**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: frontend
        image: YOUR_DOCKERHUB_USERNAME/weather-frontend:v1.0  # ← CHANGE THIS
```

### Image Naming Convention

Format: `<dockerhub-username>/<image-name>:<tag>`

Examples:
- `johndoe/city-service:v1.0`
- `johndoe/weather-service:v1.0`
- `johndoe/weather-frontend:v1.0`

---

## 💾 Database Operations

### Method 1: Using the Test Script

```bash
./test-database.sh
```

Interactive menu with options to:
1. View table structure
2. Count records
3. View recent searches
4. Query by city
5. View statistics
6. Connect to psql shell

### Method 2: Direct PostgreSQL Access

```bash
# Get pod name
POD=$(kubectl get pods -n weather-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

# Connect to PostgreSQL
kubectl exec -it $POD -n weather-app -- psql -U weatheruser -d weatherdb
```

**Useful SQL Queries**:

```sql
-- View table structure
\d weather_searches

-- Count total searches
SELECT COUNT(*) FROM weather_searches;

-- View last 10 searches
SELECT city_name, temperature, searched_at 
FROM weather_searches 
ORDER BY searched_at DESC 
LIMIT 10;

-- Most searched cities
SELECT city_name, COUNT(*) as count 
FROM weather_searches 
GROUP BY city_name 
ORDER BY count DESC 
LIMIT 5;

-- Average temperature by city
SELECT city_name, AVG(temperature) as avg_temp 
FROM weather_searches 
GROUP BY city_name;

-- Exit
\q
```

### Method 3: Using kubectl exec

```bash
# One-liner queries
kubectl exec -it $POD -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT COUNT(*) FROM weather_searches;"

kubectl exec -it $POD -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT * FROM weather_searches ORDER BY searched_at DESC LIMIT 5;"
```

### Verify Data is Stored

1. **Search for a city** in the frontend (e.g., "London")
2. **Run this command**:
   ```bash
   ./test-database.sh
   # Choose option 3: View last 10 searches
   ```
3. **You should see** your London search with timestamp

---

## 🧪 Testing the Deployment

### Automated Testing

```bash
./test-k8s.sh
```

This script tests:
- Pod status
- Service connectivity
- API endpoints
- Database connection
- Frontend accessibility

### Manual Testing

#### Test 1: Check Pod Status

```bash
kubectl get pods -n weather-app
```

All pods should be `Running` with `READY 1/1`.

#### Test 2: Check Logs

```bash
# City Service logs
kubectl logs -f deployment/city-service -n weather-app

# Weather Service logs
kubectl logs -f deployment/weather-service -n weather-app

# PostgreSQL logs
kubectl logs -f deployment/postgres -n weather-app
```

#### Test 3: Test APIs

```bash
# Get service URLs
CITY_URL=$(minikube service city-service -n weather-app --url)
WEATHER_URL=$(minikube service weather-service -n weather-app --url)

# Test City Service
curl $CITY_URL/health
curl "$CITY_URL/api/cities/search?q=London"

# Test Weather Service
curl $WEATHER_URL/health
curl "$WEATHER_URL/api/weather?city=London"
curl "$WEATHER_URL/api/weather/history?limit=5"
```

#### Test 4: Test Frontend

```bash
# Open in browser
minikube service frontend-service -n weather-app

# Or get URL
minikube service frontend-service -n weather-app --url
```

---

## 🐛 Troubleshooting

### Issue 1: Pods Not Starting

**Symptom**: Pods stuck in `Pending` or `CrashLoopBackOff`

**Diagnosis**:
```bash
kubectl get pods -n weather-app
kubectl describe pod <pod-name> -n weather-app
kubectl logs <pod-name> -n weather-app
```

**Common Causes**:
1. **Image pull error**: Check Docker Hub image name/tag
2. **Resource limits**: Minikube may need more memory
3. **Missing secrets**: Check API key in secrets.yaml

**Solutions**:
```bash
# Restart Minikube with more resources
minikube delete
minikube start --cpus=4 --memory=4096

# Check secret exists
kubectl get secret weather-app-secrets -n weather-app

# Recreate deployment
kubectl delete deployment weather-service -n weather-app
kubectl apply -f k8s/08-weather-service-deployment.yaml
```

### Issue 2: Cannot Access Services

**Symptom**: `minikube service` command doesn't work

**Solution 1: Check Minikube IP**:
```bash
minikube ip
# Use this IP with NodePort
# Example: http://192.168.49.2:30080
```

**Solution 2: Port Forward**:
```bash
kubectl port-forward -n weather-app service/frontend-service 8080:80
# Access at http://localhost:8080
```

**Solution 3: Minikube Tunnel** (For LoadBalancer type):
```bash
minikube tunnel
# In another terminal, get external IP
kubectl get svc -n weather-app
```

### Issue 3: Database Connection Fails

**Symptom**: Weather service can't connect to PostgreSQL

**Diagnosis**:
```bash
# Check PostgreSQL is running
kubectl get pods -n weather-app -l app=postgres

# Check PostgreSQL logs
kubectl logs -f deployment/postgres -n weather-app

# Check service
kubectl get svc postgres-service -n weather-app
```

**Solution**:
```bash
# Verify database credentials
kubectl get secret weather-app-secrets -n weather-app -o yaml

# Restart weather service
kubectl rollout restart deployment/weather-service -n weather-app

# Check weather service logs
kubectl logs -f deployment/weather-service -n weather-app
```

### Issue 4: API Returns 401 Unauthorized

**Cause**: Invalid or missing OpenWeatherMap API key

**Solution**:
```bash
# Update secret
kubectl delete secret weather-app-secrets -n weather-app
# Edit k8s/02-secrets.yaml with correct API key
kubectl apply -f k8s/02-secrets.yaml

# Restart deployments to pick up new secret
kubectl rollout restart deployment/city-service -n weather-app
kubectl rollout restart deployment/weather-service -n weather-app
```

### Issue 5: PersistentVolumeClaim Pending

**Symptom**: PVC stuck in `Pending` state

**Diagnosis**:
```bash
kubectl get pvc -n weather-app
kubectl describe pvc postgres-pvc -n weather-app
```

**Solution**:
```bash
# Check storage class
kubectl get storageclass

# Minikube should have 'standard' storage class by default
# Delete and recreate PVC
kubectl delete pvc postgres-pvc -n weather-app
kubectl apply -f k8s/03-pvc.yaml
```

### General Debugging Commands

```bash
# View all resources
kubectl get all -n weather-app

# Describe any resource
kubectl describe <resource-type> <name> -n weather-app

# View logs with timestamps
kubectl logs <pod-name> -n weather-app --timestamps

# Stream logs
kubectl logs -f <pod-name> -n weather-app

# Execute command in pod
kubectl exec -it <pod-name> -n weather-app -- /bin/sh

# View events
kubectl get events -n weather-app --sort-by='.lastTimestamp'
```

---

## 📈 Scaling and Management

### Horizontal Scaling (More Pods)

```bash
# Scale city-service to 3 replicas
kubectl scale deployment city-service --replicas=3 -n weather-app

# Scale weather-service to 5 replicas
kubectl scale deployment weather-service --replicas=5 -n weather-app

# View scaling
kubectl get pods -n weather-app -l app=weather-service

# Check how traffic is distributed
kubectl get endpoints weather-service -n weather-app
```

### Auto-Scaling (Horizontal Pod Autoscaler)

Create HPA to scale based on CPU:

```bash
# Auto-scale between 2-10 replicas based on CPU usage
kubectl autoscale deployment weather-service \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n weather-app

# View HPA status
kubectl get hpa -n weather-app

# Describe HPA
kubectl describe hpa weather-service -n weather-app
```

### Resource Management

**View Resource Usage**:
```bash
# Pod resource usage
kubectl top pods -n weather-app

# Node resource usage
kubectl top nodes
```

**Update Resource Limits**:

Edit deployment YAML:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

Apply changes:
```bash
kubectl apply -f k8s/08-weather-service-deployment.yaml
```

### Rolling Updates

**Update Image**:
```bash
# Build new version
docker build -t $DOCKERHUB_USERNAME/weather-service:v1.1 ./weather-service
docker push $DOCKERHUB_USERNAME/weather-service:v1.1

# Update deployment
kubectl set image deployment/weather-service \
  weather-service=$DOCKERHUB_USERNAME/weather-service:v1.1 \
  -n weather-app

# Watch rollout
kubectl rollout status deployment/weather-service -n weather-app

# View rollout history
kubectl rollout history deployment/weather-service -n weather-app
```

**Rollback**:
```bash
# Rollback to previous version
kubectl rollout undo deployment/weather-service -n weather-app

# Rollback to specific revision
kubectl rollout undo deployment/weather-service --to-revision=2 -n weather-app
```

### Configuration Changes

**Update Secrets**:
```bash
# Delete existing secret
kubectl delete secret weather-app-secrets -n weather-app

# Update k8s/02-secrets.yaml with new values

# Apply new secret
kubectl apply -f k8s/02-secrets.yaml

# Restart pods to pick up new secret
kubectl rollout restart deployment/city-service -n weather-app
kubectl rollout restart deployment/weather-service -n weather-app
```

**Update ConfigMap**:
```bash
# Update k8s/01-configmap.yaml

# Apply changes
kubectl apply -f k8s/01-configmap.yaml

# Restart PostgreSQL (if needed)
kubectl rollout restart deployment/postgres -n weather-app
```

---

## 🧹 Cleanup

### Option 1: Delete Namespace (Removes Everything)

```bash
# Delete entire namespace and all resources
kubectl delete namespace weather-app

# This removes:
# - All deployments
# - All services
# - All pods
# - ConfigMaps
# - Secrets
# - PersistentVolumeClaims
```

**Note**: PersistentVolumes may remain. Check with:
```bash
kubectl get pv
```

### Option 2: Delete Individual Resources

```bash
# Delete deployments
kubectl delete deployment city-service weather-service frontend postgres -n weather-app

# Delete services
kubectl delete svc city-service weather-service frontend-service postgres-service -n weather-app

# Delete PVC (this deletes database data!)
kubectl delete pvc postgres-pvc -n weather-app

# Delete ConfigMap and Secrets
kubectl delete configmap postgres-init-script -n weather-app
kubectl delete secret weather-app-secrets -n weather-app
```

### Option 3: Delete Using Manifest Files

```bash
# Delete all resources defined in k8s/ directory
kubectl delete -f k8s/
```

### Stop Minikube

```bash
# Stop Minikube (keeps data)
minikube stop

# Delete Minikube cluster (removes all data)
minikube delete
```

### Clean Docker Images

```bash
# Remove local images
docker rmi $DOCKERHUB_USERNAME/city-service:v1.0
docker rmi $DOCKERHUB_USERNAME/weather-service:v1.0
docker rmi $DOCKERHUB_USERNAME/weather-frontend:v1.0

# Clean unused images
docker system prune -a
```

---

## 📚 Kubernetes vs Docker Compose Comparison

| Aspect | Docker Compose | Kubernetes |
|--------|----------------|------------|
| **Scope** | Single machine | Multi-machine cluster |
| **Orchestration** | Basic | Advanced |
| **Scaling** | Manual | Automatic |
| **Load Balancing** | Limited | Built-in |
| **Self-Healing** | No | Yes (pod restart) |
| **Rolling Updates** | No | Yes |
| **Health Checks** | Basic | Advanced (liveness, readiness) |
| **Secrets Management** | Environment files | Secrets API |
| **Configuration** | .env files | ConfigMaps, Secrets |
| **Storage** | Volumes | PersistentVolumes, PVCs |
| **Networking** | Simple bridge | Advanced (Services, Ingress) |
| **Use Case** | Development | Production |

---

## 🎓 Key Concepts Summary

### What You've Learned:

1. **Kubernetes Architecture**:
   - Pods, Deployments, Services
   - Namespaces for isolation
   - ConfigMaps and Secrets for configuration

2. **Container Orchestration**:
   - Replica management
   - Load balancing
   - Health checks
   - Rolling updates

3. **Persistent Storage**:
   - PersistentVolumes
   - PersistentVolumeClaims
   - StatefulSets (for databases)

4. **Networking**:
   - ClusterIP (internal)
   - NodePort (external access)
   - Service discovery (DNS)

5. **DevOps Practices**:
   - Docker image versioning
   - Registry management (Docker Hub)
   - Declarative infrastructure (YAML)

---

## 🔧 Useful kubectl Commands

### Pods

```bash
# List pods
kubectl get pods -n weather-app

# Wide output (shows node, IP)
kubectl get pods -n weather-app -o wide

# Watch pods (live updates)
kubectl get pods -n weather-app --watch

# Describe pod
kubectl describe pod <pod-name> -n weather-app

# Pod logs
kubectl logs <pod-name> -n weather-app

# Follow logs
kubectl logs -f <pod-name> -n weather-app

# Previous logs (if pod crashed)
kubectl logs <pod-name> -n weather-app --previous

# Execute command in pod
kubectl exec -it <pod-name> -n weather-app -- /bin/bash

# Delete pod (will be recreated by deployment)
kubectl delete pod <pod-name> -n weather-app
```

### Deployments

```bash
# List deployments
kubectl get deployments -n weather-app

# Describe deployment
kubectl describe deployment weather-service -n weather-app

# Scale deployment
kubectl scale deployment weather-service --replicas=3 -n weather-app

# Update image
kubectl set image deployment/weather-service weather-service=new-image:tag -n weather-app

# Rollout status
kubectl rollout status deployment/weather-service -n weather-app

# Rollout history
kubectl rollout history deployment/weather-service -n weather-app

# Rollback
kubectl rollout undo deployment/weather-service -n weather-app

# Restart deployment
kubectl rollout restart deployment/weather-service -n weather-app
```

### Services

```bash
# List services
kubectl get svc -n weather-app

# Describe service
kubectl describe svc weather-service -n weather-app

# Get endpoints
kubectl get endpoints weather-service -n weather-app

# Port forward
kubectl port-forward svc/weather-service 8080:5002 -n weather-app
```

### General

```bash
# Get all resources
kubectl get all -n weather-app

# Get resource YAML
kubectl get deployment weather-service -n weather-app -o yaml

# Edit resource (opens in editor)
kubectl edit deployment weather-service -n weather-app

# Apply changes from file
kubectl apply -f k8s/08-weather-service-deployment.yaml

# Delete resource
kubectl delete -f k8s/08-weather-service-deployment.yaml

# View events
kubectl get events -n weather-app --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n weather-app
kubectl top nodes
```

---

## 🚀 Next Steps

### 1. Add Ingress Controller

Replace NodePort with Ingress for better routing:

```bash
# Enable ingress addon
minikube addons enable ingress

# Create ingress.yaml
kubectl apply -f ingress.yaml
```

### 2. Add Monitoring

**Prometheus + Grafana**:
```bash
# Install using Helm
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 3. Add CI/CD Pipeline

**GitHub Actions example**:
```yaml
name: Deploy to Kubernetes
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build and push
        run: |
          docker build -t ${{ secrets.DOCKERHUB_USERNAME }}/weather-service:${{ github.sha }} .
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/weather-service:${{ github.sha }}
      - name: Update Kubernetes
        run: kubectl set image deployment/weather-service weather-service=${{ secrets.DOCKERHUB_USERNAME }}/weather-service:${{ github.sha }}
```

### 4. Move to Cloud

Deploy to:
- **Google Kubernetes Engine (GKE)**
- **Amazon EKS**
- **Azure AKS**
- **DigitalOcean Kubernetes**

### 5. Implement Service Mesh

Add **Istio** for:
- Advanced traffic management
- Service-to-service authentication
- Distributed tracing
- Circuit breaking

---

## 📖 Additional Resources

### Official Documentation

- **Kubernetes**: https://kubernetes.io/docs/
- **Minikube**: https://minikube.sigs.k8s.io/docs/
- **kubectl**: https://kubernetes.io/docs/reference/kubectl/
- **Docker**: https://docs.docker.com/

### Tutorials

- Kubernetes Basics: https://kubernetes.io/docs/tutorials/kubernetes-basics/
- Kubernetes by Example: https://kubernetesbyexample.com/
- Play with Kubernetes: https://labs.play-with-k8s.com/

### Books

- "Kubernetes Up & Running" by Kelsey Hightower
- "The Kubernetes Book" by Nigel Poulton
- "Kubernetes in Action" by Marko Luksa

---

## 🤝 Contributing

Feel free to:
- Fork this project
- Add new features
- Improve documentation
- Report issues

---

## 📄 License

This project is open source and available for learning purposes.

---

## 🎉 Congratulations!

You now have a fully functional microservices application running on Kubernetes! You've learned:

✅ Docker containerization  
✅ Docker Hub registry  
✅ Kubernetes deployments  
✅ Service networking  
✅ Persistent storage  
✅ Secrets management  
✅ Health checks  
✅ Scaling  
✅ Rolling updates  

**Happy Learning!** 🚀

---

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review pod logs: `kubectl logs <pod-name> -n weather-app`
3. Check events: `kubectl get events -n weather-app`
4. Verify all prerequisites are installed
5. Ensure Minikube has enough resources

For more help, refer to the official Kubernetes documentation or community forums.

# deploy_in_minikube_k8
