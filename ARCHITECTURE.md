# Kubernetes Architecture Deep Dive

Complete explanation of the Weather Microservices application architecture on Kubernetes.

---

## Table of Contents

- [Overview](#overview)
- [Kubernetes Components](#kubernetes-components)
- [Networking Architecture](#networking-architecture)
- [Storage Architecture](#storage-architecture)
- [Security Architecture](#security-architecture)
- [Deployment Strategy](#deployment-strategy)
- [Scaling Strategy](#scaling-strategy)
- [Comparison with Docker Compose](#comparison-with-docker-compose)

---

## Overview

### System Components

```
Kubernetes Cluster (Minikube)
│
├── Namespace: weather-app
│   │
│   ├── Frontend (2 replicas)
│   │   ├── Pod 1: Nginx serving static files
│   │   └── Pod 2: Nginx serving static files
│   │
│   ├── City Service (2 replicas)
│   │   ├── Pod 1: Flask app + Gunicorn
│   │   └── Pod 2: Flask app + Gunicorn
│   │
│   ├── Weather Service (2 replicas)
│   │   ├── Pod 1: Flask app + Gunicorn
│   │   └── Pod 2: Flask app + Gunicorn
│   │
│   └── PostgreSQL (1 replica)
│       └── Pod: PostgreSQL 15
│
├── Services
│   ├── frontend-service (NodePort: 30080)
│   ├── city-service (NodePort: 30001)
│   ├── weather-service (NodePort: 30002)
│   └── postgres-service (ClusterIP: 5432)
│
├── Storage
│   ├── PersistentVolumeClaim: postgres-pvc (1Gi)
│   └── PersistentVolume: (auto-provisioned)
│
└── Configuration
    ├── ConfigMap: postgres-init-script
    └── Secret: weather-app-secrets
```

---

## Kubernetes Components

### 1. Namespace

**Purpose**: Logical isolation and resource organization

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: weather-app
```

**Benefits**:
- Isolates resources from other applications
- Applies policies at namespace level
- Prevents naming conflicts
- Enables resource quotas

**Usage**:
```bash
# All commands target this namespace
kubectl get pods -n weather-app
kubectl apply -f manifest.yaml -n weather-app
```

---

### 2. Pods

**What**: Smallest deployable unit in Kubernetes

**Pod Lifecycle**:
```
Pending → Running → Succeeded/Failed
    ↓
  (ContainerCreating)
    ↓
  (Ready)
```

**Example Pod Spec** (from weather-service):
```yaml
spec:
  containers:
  - name: weather-service
    image: username/weather-service:v1.0
    ports:
    - containerPort: 5002
    env:
    - name: DB_HOST
      value: "postgres-service"
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
```

**Key Concepts**:
- **Multi-container pods**: We use single-container pods
- **Init containers**: Could be added for setup tasks
- **Sidecar containers**: Could add logging/monitoring sidecars

---

### 3. Deployments

**Purpose**: Manage replica sets and enable rolling updates

**Deployment Hierarchy**:
```
Deployment
  └── ReplicaSet
      └── Pods (replicas)
```

**Example** (weather-service):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather-service
spec:
  replicas: 2  # 2 pods for high availability
  selector:
    matchLabels:
      app: weather-service
  template:
    metadata:
      labels:
        app: weather-service
    spec:
      containers:
      - name: weather-service
        image: username/weather-service:v1.0
```

**Deployment Features**:

1. **Replica Management**:
   - Ensures desired number of pods running
   - Replaces failed pods automatically

2. **Rolling Updates**:
   ```bash
   kubectl set image deployment/weather-service \
     weather-service=username/weather-service:v1.1
   ```
   - Updates pods gradually
   - No downtime
   - Can rollback if issues occur

3. **Rollback**:
   ```bash
   kubectl rollout undo deployment/weather-service
   ```

**Why Not StatefulSet?**
- StatefulSets for stateful apps (databases)
- Deployments for stateless apps (our services)
- PostgreSQL could use StatefulSet for multi-replica setup

---

### 4. Services

**Purpose**: Stable network endpoint for pods

**Service Types in Our App**:

#### ClusterIP (postgres-service)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
spec:
  type: ClusterIP  # Default, internal only
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
```

**Characteristics**:
- Only accessible within cluster
- Gets internal DNS name: `postgres-service.weather-app.svc.cluster.local`
- Used for database (security)

#### NodePort (city-service, weather-service, frontend-service)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: city-service
spec:
  type: NodePort
  ports:
  - port: 5001
    targetPort: 5001
    nodePort: 30001  # External port
  selector:
    app: city-service
```

**Characteristics**:
- Accessible from outside cluster
- Each node exposes the port
- Port range: 30000-32767
- Minikube provides access via `minikube service`

**Service Discovery**:
```
weather-service connects to PostgreSQL using:
  "postgres-service" (short name)
  
Kubernetes DNS resolves to:
  postgres-service.weather-app.svc.cluster.local
  
Which load-balances to:
  PostgreSQL pod IP
```

---

### 5. ConfigMaps

**Purpose**: Store non-sensitive configuration

**Our ConfigMap**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init-script
data:
  init.sql: |
    CREATE TABLE weather_searches (...);
```

**Usage in Pod**:
```yaml
volumeMounts:
- name: init-script
  mountPath: /docker-entrypoint-initdb.d
volumes:
- name: init-script
  configMap:
    name: postgres-init-script
```

**When to Use**:
- Configuration files
- Environment variables (non-sensitive)
- Scripts
- Command-line arguments

---

### 6. Secrets

**Purpose**: Store sensitive data (encrypted at rest in etcd)

**Our Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: weather-app-secrets
type: Opaque
stringData:
  openweather-api-key: "actual_key_here"
  postgres-password: "weatherpass"
```

**Usage in Pod**:
```yaml
env:
- name: OPENWEATHER_API_KEY
  valueFrom:
    secretKeyRef:
      name: weather-app-secrets
      key: openweather-api-key
```

**Security Best Practices**:
- Never commit secrets to Git
- Use RBAC to control access
- Consider external secret managers (Vault, AWS Secrets Manager)
- Rotate regularly

---

### 7. PersistentVolumes & PersistentVolumeClaims

**Architecture**:
```
PersistentVolumeClaim (PVC) ← Pod mounts this
        ↓ (binds to)
PersistentVolume (PV)       ← Actual storage
        ↓ (uses)
Storage Backend             ← Minikube: hostPath
```

**Our PVC**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce  # Single pod can mount
  resources:
    requests:
      storage: 1Gi
```

**Access Modes**:
- `ReadWriteOnce` (RWO): One pod (our setup)
- `ReadOnlyMany` (ROX): Multiple pods, read-only
- `ReadWriteMany` (RWX): Multiple pods, read-write

**Storage Classes**:
```bash
# Minikube default
kubectl get storageclass
NAME                 PROVISIONER
standard (default)   k8s.io/minikube-hostpath
```

**Why PVC Instead of Direct PV?**
- Abstraction: Pods don't care about storage details
- Dynamic provisioning: PV created automatically
- Portability: Same PVC works on different clusters

---

## Networking Architecture

### DNS Resolution

Kubernetes provides built-in DNS for service discovery:

```
Service Name: postgres-service
Full DNS:     postgres-service.weather-app.svc.cluster.local

Components:
  postgres-service  = Service name
  weather-app       = Namespace
  svc               = Service type
  cluster.local     = Cluster domain
```

**Short Names Work** (within same namespace):
```python
DB_HOST = "postgres-service"  # Works!
# Kubernetes expands to full DNS
```

### Network Policies (Not Implemented, But Could Be)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
spec:
  podSelector:
    matchLabels:
      app: postgres
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: weather-service
    ports:
    - protocol: TCP
      port: 5432
```

This would:
- Only allow weather-service to access PostgreSQL
- Block all other traffic

---

## Storage Architecture

### PostgreSQL Data Persistence

```
PostgreSQL Pod
    │
    ├─ Container writes to: /var/lib/postgresql/data/pgdata
    │
    └─ Mounted from: PersistentVolume
                          │
                          └─ Backed by: Minikube host storage
```

**What Persists?**
- Database tables
- Indexes
- Configuration changes
- WAL logs

**What Doesn't Persist?**
- Pod metadata
- Container logs (use logging solution)
- Temporary files in container

**Data Lifecycle**:
1. Pod created → PVC binds to PV
2. Container writes data → Stored in PV
3. Pod deleted → PV remains
4. New pod created → Binds to same PV
5. Data still available ✓

---

## Security Architecture

### 1. Pod Security

**Non-root Users**:
```dockerfile
# In Dockerfile
RUN useradd -m -u 1000 appuser
USER appuser
```

**Why?**
- Limit damage if container compromised
- Follow principle of least privilege

### 2. RBAC (Role-Based Access Control)

Not implemented in this project, but production should have:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

### 3. Network Security

**Current**:
- Services isolated by namespace
- Only NodePort services accessible externally

**Production Improvements**:
- Add Ingress with TLS
- Implement NetworkPolicies
- Use service mesh (Istio) for mTLS

### 4. Secrets Management

**Current**:
- Kubernetes Secrets (base64 encoded)

**Production**:
- External secret managers:
  - HashiCorp Vault
  - AWS Secrets Manager
  - Google Secret Manager
- Sealed Secrets for GitOps

---

## Deployment Strategy

### Current Strategy: Recreate

**How it works**:
1. Kill all old pods
2. Create all new pods
3. Brief downtime during transition

### Better Strategy: Rolling Update (Built-in)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max new pods during update
      maxUnavailable: 0  # Max old pods down during update
```

**How it works**:
1. Create 1 new pod
2. Wait for it to be ready
3. Delete 1 old pod
4. Repeat until all updated
5. Zero downtime ✓

### Advanced: Blue-Green Deployment

```yaml
# Blue deployment (current)
selector:
  app: weather-service
  version: blue

# Green deployment (new)
selector:
  app: weather-service
  version: green

# Switch service selector when ready
```

---

## Scaling Strategy

### Horizontal Scaling

**Manual**:
```bash
kubectl scale deployment weather-service --replicas=5
```

**Automatic** (HPA - Horizontal Pod Autoscaler):
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: weather-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: weather-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**How HPA Works**:
1. Monitor CPU usage every 15s
2. If average > 70% → Add pod
3. If average < 70% → Remove pod
4. Stay within 2-10 pods

### Vertical Scaling

**Increase Resources**:
```yaml
resources:
  requests:
    memory: "256Mi"  # Was 128Mi
    cpu: "200m"      # Was 100m
```

**VPA (Vertical Pod Autoscaler)**:
- Automatically adjusts resource requests
- Requires installation
- Restarts pods to apply changes

---

## Comparison with Docker Compose

### Resource Definitions

**Docker Compose**:
```yaml
services:
  weather-service:
    build: ./weather-service
    ports:
      - "5002:5002"
    depends_on:
      - postgres
    environment:
      - DB_HOST=postgres
```

**Kubernetes** (requires 2 files):
```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather-service
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: weather-service
        image: user/weather-service:v1.0
        
# Service
apiVersion: v1
kind: Service
metadata:
  name: weather-service
spec:
  type: NodePort
  ports:
  - port: 5002
```

### Key Differences

| Feature | Docker Compose | Kubernetes |
|---------|----------------|------------|
| **Complexity** | Simple YAML | Multiple YAML files |
| **Replicas** | Manual `--scale` | Built-in `replicas` |
| **Health Checks** | Basic | Advanced (liveness/readiness) |
| **Updates** | Stop/start | Rolling updates |
| **Storage** | Named volumes | PV/PVC abstraction |
| **Networking** | Bridge network | Services + DNS |
| **Secrets** | .env files | Secrets API |
| **Load Balancing** | Round-robin | Service abstraction |
| **Self-healing** | No | Yes |
| **Cluster** | Single host | Multi-host |

### Migration Path

1. **Dockerize** your app (Dockerfile)
2. **Docker Compose** for local dev
3. **Kubernetes** for production
4. **Managed K8s** (GKE/EKS/AKS) for scale

---

## Production Considerations

### 1. High Availability

**Current**: 2 replicas per service  
**Production**: 3+ replicas, multi-zone

### 2. Monitoring

**Add**:
- Prometheus for metrics
- Grafana for dashboards
- Alertmanager for alerts

### 3. Logging

**Add**:
- EFK stack (Elasticsearch, Fluentd, Kibana)
- Or ELK stack (Elasticsearch, Logstash, Kibana)

### 4. Ingress

Replace NodePort with Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: weather-ingress
spec:
  rules:
  - host: weather.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: frontend-service
            port: 80
```

### 5. Database

**Current**: Single PostgreSQL pod  
**Production**: 
- StatefulSet with 3 replicas
- Or managed database (Cloud SQL, RDS)

### 6. CI/CD

Automate deployment:
- GitHub Actions
- GitLab CI
- Jenkins
- ArgoCD (GitOps)

---

## Architecture Patterns Used

### 1. Microservices
- Independent services
- Each with own responsibility
- Communicate via APIs

### 2. 12-Factor App
- ✅ Codebase: Single repo
- ✅ Dependencies: Explicitly declared
- ✅ Config: Environment variables
- ✅ Backing services: Attached resources
- ✅ Build/Release/Run: Separate stages
- ✅ Processes: Stateless
- ✅ Port binding: Self-contained
- ✅ Concurrency: Scale via replicas
- ✅ Disposability: Fast startup/shutdown
- ✅ Dev/Prod parity: Same containers
- ✅ Logs: Stdout/stderr
- ✅ Admin processes: One-off tasks

### 3. Cloud Native
- Containerized
- Orchestrated (Kubernetes)
- Microservices architecture
- API-driven
- Observable

---

This architecture provides a solid foundation for understanding Kubernetes and modern cloud-native applications!

