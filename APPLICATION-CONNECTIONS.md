# Application Connections & Resource Flow

This diagram shows how frontend, backend, and database connect, share secrets, and communicate.

## Service Communication Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          EKS CLUSTER                                      │
│                                                                           │
│  Namespace: frontend                                                     │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Frontend Pods (React)                                            │  │
│  │  Image: galihhhp/react-frontend:2.0.0                             │  │
│  │                                                                    │  │
│  │  Environment Variables (from ConfigMap):                          │  │
│  │    API_URL: "http://localhost:3000"                               │  │
│  │    FEATURE_EDIT_TASK: "true"                                      │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │ Container                                                    │ │  │
│  │  │ Port: 80                                                     │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
│                                │                                         │
│                                │ HTTP requests                           │
│                                ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Service: frontend                                                │  │
│  │  Type: ClusterIP                                                  │  │
│  │  Port: 80 → TargetPort: 80                                        │  │
│  │  Selector: app=frontend                                           │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                │ API calls
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Namespace: backend                                                      │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Service: backend                                                 │  │
│  │  Type: ClusterIP                                                  │  │
│  │  Port: 3000 → TargetPort: 3000                                    │  │
│  │  Selector: app=backend                                            │  │
│  │  DNS: backend.backend.svc.cluster.local                           │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
│                                │                                         │
│                                ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Backend Pods (Node.js)                                           │  │
│  │  Image: galihhhp/task-services:2.0.0                              │  │
│  │                                                                    │  │
│  │  Environment Variables (from ConfigMap):                          │  │
│  │    NODE_ENV: "production"                                         │  │
│  │    DB_HOST: "database"    ← Service name                          │  │
│  │    DB_PORT: "5432"                                                │  │
│  │    DB_NAME: "postgres"                                            │  │
│  │    DB_USER: "postgres"                                            │  │
│  │                                                                    │  │
│  │  Secrets (from Kubernetes Secret):                                │  │
│  │    DB_PASSWORD: ← Read from secret "database"                     │  │
│  │    └── secretName: database                                       │  │
│  │    └── key: postgres-password                                     │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │ Container                                                    │ │  │
│  │  │ Port: 3000                                                   │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
│                                │                                         │
│                                │ SQL queries                             │
│                                ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Service: database                                                │  │
│  │  Type: ClusterIP                                                  │  │
│  │  Port: 5432 → TargetPort: 5432                                    │  │
│  │  Selector: app.kubernetes.io/name=postgresql                      │  │
│  │  DNS: database.database.svc.cluster.local                         │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
└─────────────────────────────────┼──────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Namespace: database                                                     │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  PostgreSQL StatefulSet (Bitnami)                                 │  │
│  │  Image: bitnami/postgresql:17                                     │  │
│  │                                                                    │  │
│  │  Reads Password from Secret:                                      │  │
│  │    Secret Name: database                                          │  │
│  │    Key: postgres-password                                         │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │ Container                                                    │ │  │
│  │  │ Port: 5432                                                   │ │  │
│  │  │ Volume: /var/lib/postgresql/data (10Gi PVC)                  │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Secret: database (Created by Bitnami)                            │  │
│  │  Type: Opaque                                                     │  │
│  │  Data:                                                            │  │
│  │    postgres-password: Y2hhbmdlbWUxMjM= (base64)                   │  │
│  │    password: Y2hhbmdlbWUxMjM= (base64)                            │  │
│  │                                                                    │  │
│  │  Plain text: "changeme123" (dev) or "devpassword123" (dev env)   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Secret Sharing Mechanism

### How Backend Gets Database Password

```
Step 1: Database Deployment
┌─────────────────────────────────────┐
│ Helm renders database chart         │
│                                     │
│ values.yaml:                        │
│   postgresPassword: "changeme123"   │
│                                     │
│ Bitnami creates Secret:             │
│   name: database                    │
│   data:                             │
│     postgres-password: base64(...)  │
└──────────────┬──────────────────────┘
               │
               │ Secret created in database namespace
               ▼
┌─────────────────────────────────────┐
│ Kubernetes Secret                   │
│ Name: database                      │
│ Namespace: database                 │
└─────────────────────────────────────┘
               │
               │ Backend references this secret
               ▼
Step 2: Backend Deployment
┌─────────────────────────────────────┐
│ Backend pod definition              │
│                                     │
│ env:                                │
│ - name: DB_PASSWORD                 │
│   valueFrom:                        │
│     secretKeyRef:                   │
│       name: database  ← Secret name │
│       key: postgres-password        │
└──────────────┬──────────────────────┘
               │
               │ Kubernetes injects value
               ▼
┌─────────────────────────────────────┐
│ Backend Container                   │
│                                     │
│ Environment Variable:               │
│   DB_PASSWORD=changeme123  ✅       │
│                                     │
│ Application code:                   │
│   const client = new Client({      │
│     host: 'database',              │
│     password: process.env.DB_PASSWORD│
│   })                                │
└─────────────────────────────────────┘
```

---

## ConfigMap vs Secret

### ConfigMap (Non-Sensitive Data)

```
Frontend ConfigMap
├── API_URL: "http://localhost:3000"
├── FEATURE_EDIT_TASK: "true"
├── FEATURE_DELETE_TASK: "true"
└── VITE_APP_VERSION: "2.0.0"

Backend ConfigMap
├── NODE_ENV: "production"
├── DB_HOST: "database"  ← Service DNS name
├── DB_PORT: "5432"
├── DB_NAME: "postgres"
└── DB_USER: "postgres"

Purpose: Configuration that's OK to expose
Storage: Plain text (not base64 encoded)
```

### Secret (Sensitive Data)

```
Database Secret
├── postgres-password: "changeme123"
└── password: "changeme123"

Purpose: Sensitive credentials
Storage: Base64 encoded (not encrypted!)
Access: Backend reads via secretKeyRef

⚠️ Note: Secrets are base64 (NOT encrypted)
For production: Use AWS Secrets Manager
```

---

## DNS Service Discovery

### How Services Find Each Other

```
Backend Pod wants to connect to database:

1. Backend uses: DB_HOST="database"
   
2. Kubernetes DNS resolves:
   "database" → "database.database.svc.cluster.local"
   
   Format: <service-name>.<namespace>.svc.cluster.local
   
3. DNS returns: ClusterIP (e.g., 10.100.50.10)

4. Backend connects to: 10.100.50.10:5432

5. Kubernetes routes to: Healthy database pod

Same namespace:     "backend" works
Cross namespace:    "backend.backend" or full DNS
```

---

## Resource Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│  DEPLOYMENT ORDER & DEPENDENCIES                             │
└─────────────────────────────────────────────────────────────┘

Database (Wave 0)
  ├── No dependencies
  ├── Creates: Secret (postgres-password)
  ├── Creates: Service (database:5432)
  └── Creates: PVC (persistent storage)
             │
             │ Required by Backend
             ▼
Backend (Wave 1)
  ├── Depends: Database service ready
  ├── Reads: Secret "database"
  ├── Connects: database:5432
  └── Creates: Service (backend:3000)
             │
             │ Required by Frontend
             ▼
Frontend (Wave 2)
  ├── Depends: Backend service ready
  ├── Reads: ConfigMap (API_URL)
  └── Connects: backend:3000 (via API_URL)
```

---

## Network Policies (When Enabled)

### Production Network Isolation

```
┌──────────────┐
│  Frontend    │
└──────┬───────┘
       │
       │ ✅ Allowed: frontend → backend (port 3000)
       │ ❌ Blocked: frontend → database (port 5432)
       ▼
┌──────────────┐
│  Backend     │
└──────┬───────┘
       │
       │ ✅ Allowed: backend → database (port 5432)
       ▼
┌──────────────┐
│  Database    │
└──────────────┘

NetworkPolicy Rules:
├── database: Only accept from backend
├── backend: Only accept from frontend
└── frontend: Accept from anywhere (or ingress only)

Purpose: Defense in depth, limit blast radius
```

---

## Data Flow Example

### Creating a Task (End-to-End)

```
Step 1: User Action
┌─────────────────┐
│ Browser         │
│ User clicks     │
│ "Create Task"   │
└────────┬────────┘
         │
         │ HTTP POST /api/tasks
         ▼
Step 2: Frontend
┌─────────────────────────────┐
│ Frontend Pod                │
│ API_URL="http://localhost:3000" │ ← From ConfigMap
│                             │
│ fetch(`${API_URL}/tasks`)   │
└────────┬────────────────────┘
         │
         │ HTTP POST backend:3000/tasks
         ▼
Step 3: Backend
┌─────────────────────────────┐
│ Backend Pod                 │
│ DB_HOST="database"          │ ← From ConfigMap
│ DB_PASSWORD=<from-secret>   │ ← From Secret
│                             │
│ SQL: INSERT INTO main_table │
│      VALUES (...)           │
└────────┬────────────────────┘
         │
         │ TCP connection database:5432
         ▼
Step 4: Database
┌─────────────────────────────┐
│ PostgreSQL Pod              │
│ Password validated ✅       │
│                             │
│ INSERT INTO main_table(...) │
│ Data written to PVC         │
└─────────────────────────────┘
         │
         │ Response
         ▼
Backend receives: { id: 1, task: "..." }
         │
         │ JSON response
         ▼
Frontend receives: Task created ✅
         │
         │ Update UI
         ▼
User sees: New task in list 🎉
```

---

## Values File Hierarchy

### How Environment Values Override

```
Deployment: backend (dev environment)

1. Load base values.yaml:
   ┌─────────────────────────┐
   │ values.yaml             │
   │ replicaCount: 2         │
   │ image.tag: "2.0.0"      │
   │ env.NODE_ENV: "production"│
   └─────────────────────────┘
             │
             │ Override with
             ▼
2. Load values-dev.yaml:
   ┌─────────────────────────┐
   │ values-dev.yaml         │
   │ namespace: "development"│
   │ env.NODE_ENV: "development"│ ← Overrides
   └─────────────────────────┘
             │
             │ Final result
             ▼
3. Merged values:
   ┌─────────────────────────┐
   │ replicaCount: 2         │ (from base)
   │ image.tag: "2.0.0"      │ (from base)
   │ namespace: "development"│ (from dev)
   │ env.NODE_ENV: "development"│ (from dev)
   └─────────────────────────┘
```

---

## Helm Template Rendering

### From Values to Kubernetes Manifest

```
Input: values.yaml
┌─────────────────────────────┐
│ backend:                    │
│   name: "backend"           │
│   replicaCount: 2           │
│   image:                    │
│     name: "galihhhp/task-services"│
│     tag: "2.0.0"            │
│   env:                      │
│     DB_HOST: "database"     │
└─────────────────────────────┘
             │
             │ Helm renders
             ▼
Template: deployment.yaml
┌──────────────────────────────────────┐
│ apiVersion: apps/v1                  │
│ kind: Deployment                     │
│ metadata:                            │
│   name: {{ .Values.backend.name }}   │ ← Replaced
│ spec:                                │
│   replicas: {{ .Values.backend.replicaCount }}│ ← Replaced
│   template:                          │
│     spec:                            │
│       containers:                    │
│       - name: backend                │
│         image: {{ .Values.backend.image.name }}:{{ .Values.backend.image.tag }}│
│         envFrom:                     │
│         - configMapRef:              │
│             name: backend-config     │
└──────────────────────────────────────┘
             │
             │ Result
             ▼
Output: Rendered Manifest
┌──────────────────────────────────────┐
│ apiVersion: apps/v1                  │
│ kind: Deployment                     │
│ metadata:                            │
│   name: backend                      │ ✅
│ spec:                                │
│   replicas: 2                        │ ✅
│   template:                          │
│     spec:                            │
│       containers:                    │
│       - name: backend                │
│         image: galihhhp/task-services:2.0.0│ ✅
│         envFrom:                     │
│         - configMapRef:              │
│             name: backend-config     │
└──────────────────────────────────────┘
             │
             │ Applied to cluster
             ▼
┌──────────────────────────────────────┐
│ Backend Deployment created in EKS   │
│ 2 pods running ✅                    │
└──────────────────────────────────────┘
```

---

## Namespace Isolation

```
┌─────────────────────────────────────────────────────────────────┐
│                         EKS CLUSTER                              │
│                                                                  │
│  ┌───────────────────┐  ┌───────────────────┐  ┌──────────────┐│
│  │ Namespace:        │  │ Namespace:        │  │ Namespace:   ││
│  │ frontend          │  │ backend           │  │ database     ││
│  │                   │  │                   │  │              ││
│  │ Resources:        │  │ Resources:        │  │ Resources:   ││
│  │ • Deployment      │  │ • Deployment      │  │ • StatefulSet││
│  │ • Service         │  │ • Service         │  │ • Service    ││
│  │ • ConfigMap       │  │ • ConfigMap       │  │ • Secret     ││
│  │ • ServiceAccount  │  │ • ServiceAccount  │  │ • PVC        ││
│  │ • NetworkPolicy   │  │ • NetworkPolicy   │  │              ││
│  │                   │  │ • Secret (ref)    │  │              ││
│  └───────────────────┘  └───────────────────┘  └──────────────┘│
│                                                                  │
│  ┌───────────────────┐                                          │
│  │ Namespace:        │                                          │
│  │ argocd            │                                          │
│  │                   │                                          │
│  │ Resources:        │                                          │
│  │ • Applications    │                                          │
│  │ • Repos           │                                          │
│  │ • Projects        │                                          │
│  └───────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘

Benefits:
✅ Resource isolation (can't accidentally delete wrong app)
✅ RBAC per namespace (different teams, different access)
✅ NetworkPolicy enforcement
✅ Resource quotas per namespace
```

---

## ConfigMap Injection

```
ConfigMap Created:
┌─────────────────────────────┐
│ apiVersion: v1              │
│ kind: ConfigMap             │
│ metadata:                   │
│   name: backend-config      │
│   namespace: backend        │
│ data:                       │
│   DB_HOST: "database"       │
│   DB_PORT: "5432"           │
│   DB_NAME: "postgres"       │
│   DB_USER: "postgres"       │
│   NODE_ENV: "production"    │
└─────────────────────────────┘
             │
             │ Referenced in Deployment
             ▼
Pod Spec:
┌─────────────────────────────┐
│ containers:                 │
│ - name: backend             │
│   envFrom:                  │
│   - configMapRef:           │
│       name: backend-config  │ ← All data becomes env vars
└─────────────────────────────┘
             │
             │ Container sees:
             ▼
Environment Variables:
┌─────────────────────────────┐
│ DB_HOST=database            │
│ DB_PORT=5432                │
│ DB_NAME=postgres            │
│ DB_USER=postgres            │
│ NODE_ENV=production         │
└─────────────────────────────┘
```

---

## Service Discovery in Kubernetes

### How "database" Resolves to IP

```
Backend code: const host = "database";

1. DNS Lookup
   ┌─────────────────────┐
   │ Query: "database"   │
   └──────────┬──────────┘
              │
              ▼
   ┌─────────────────────────────────┐
   │ Kubernetes DNS (CoreDNS)        │
   │ Searches:                       │
   │ 1. database.backend.svc (same namespace) ❌
   │ 2. database.database.svc (exists!) ✅    │
   └──────────┬──────────────────────┘
              │
              ▼
2. Returns ClusterIP
   ┌─────────────────────┐
   │ IP: 10.100.50.10    │ (example)
   └──────────┬──────────┘
              │
              ▼
3. Backend connects to IP
   ┌─────────────────────┐
   │ TCP: 10.100.50.10:5432│
   └──────────┬──────────┘
              │
              ▼
4. Kubernetes routes to pod
   ┌─────────────────────┐
   │ Database Pod        │
   │ IP: 10.244.1.5      │ (pod IP)
   └─────────────────────┘
```

---

## Troubleshooting Connection Issues

```
Frontend can't reach Backend?
  ├─> Check service exists: kubectl get svc -n backend
  ├─> Check endpoints: kubectl get endpoints backend -n backend
  ├─> Check DNS: kubectl exec frontend-pod -- nslookup backend.backend
  └─> Check NetworkPolicy: kubectl get networkpolicy -n backend

Backend can't reach Database?
  ├─> Check DB_HOST variable: kubectl exec backend-pod -- env | grep DB_
  ├─> Check secret exists: kubectl get secret database -n database
  ├─> Check password: kubectl logs backend-pod (connection error?)
  └─> Check database ready: kubectl get pods -n database

Secret not found?
  ├─> Wrong namespace: Secret in "database", pod in "backend"
  ├─> Fix: Secrets don't cross namespaces (need to copy or use external secrets)
  └─> Current: Backend references cross-namespace (works via secretName)
```

---

## Summary

**Service Communication:**
- Frontend → Backend (HTTP via service DNS)
- Backend → Database (TCP via service DNS)

**Secret Sharing:**
- Database creates secret
- Backend reads same secret
- Both use same password ✅

**ConfigMaps:**
- Inject non-sensitive config
- Service names, ports, feature flags

**DNS:**
- Services discoverable by name
- Kubernetes DNS handles resolution
