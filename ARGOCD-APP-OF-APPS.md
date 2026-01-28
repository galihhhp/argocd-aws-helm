# ArgoCD App-of-Apps Pattern & Sync Waves

This diagram explains the app-of-apps pattern and how sync waves ensure proper deployment order.

## App-of-Apps Pattern

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Git Repository                                     │
│                                                                           │
│  argocd/applications/                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  app-of-apps-dev.yaml (Development)                              │   │
│  │  ┌────────────────────────────────────────────────────────────┐ │   │
│  │  │ Application: app-of-apps                                   │ │   │
│  │  │ Source: git@github.com:galihhhp/argocd-aws-helm.git        │ │   │
│  │  │ Branch: develop                                            │ │   │
│  │  │ Path: argocd/applications/                                 │ │   │
│  │  │                                                            │ │   │
│  │  │ This app watches the applications/ folder                 │ │   │
│  │  │ and creates child applications!                           │ │   │
│  │  └────────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│  Individual Application Manifests:                                       │
│  ├── database.yaml  (sync-wave: 0)                                      │
│  ├── backend.yaml   (sync-wave: 1)                                      │
│  └── frontend.yaml  (sync-wave: 2)                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ ArgoCD watches
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    ArgoCD in EKS Cluster                                 │
│                                                                           │
│  Step 1: Deploy app-of-apps                                              │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  kubectl apply -f app-of-apps-dev.yaml                           │   │
│  │                                                                   │   │
│  │  ArgoCD creates 1 Application: app-of-apps                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  │ app-of-apps syncs                     │
│                                  ▼                                       │
│  Step 2: app-of-apps reads argocd/applications/ folder                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Finds 3 files:                                                  │   │
│  │    • database.yaml                                               │   │
│  │    • backend.yaml                                                │   │
│  │    • frontend.yaml                                               │   │
│  │                                                                   │   │
│  │  Creates 3 child Applications automatically!                     │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  Step 3: Child applications created                                      │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │ Application:      │  │ Application:      │  │ Application:      │  │
│  │ database          │  │ backend           │  │ frontend          │  │
│  │ (sync-wave: 0)    │  │ (sync-wave: 1)    │  │ (sync-wave: 2)    │  │
│  └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘  │
│            │                      │                      │              │
│            │ Each app watches     │ its own Helm chart   │              │
│            ▼                      ▼                      ▼              │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │ apps/database/    │  │ apps/backend/     │  │ apps/frontend/    │  │
│  │ (Helm chart)      │  │ (Helm chart)      │  │ (Helm chart)      │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Sync Waves Explained

### Deployment Order (Wave 0 → 1 → 2)

```
Time: T=0
┌─────────────────────────────────────────────────────────────┐
│  Sync Wave 0: Database                                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application: database                                │   │
│  │  Status: Syncing...                                   │   │
│  │                                                       │   │
│  │  1. Create namespace "database"                      │   │
│  │  2. Deploy Bitnami PostgreSQL                        │   │
│  │  3. Create StatefulSet, Service, PVC                 │   │
│  │  4. Wait for pods Ready                              │   │
│  │  5. Wait for Service endpoints                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│                         │ Status: Healthy ✅                 │
│                         ▼                                    │
└─────────────────────────────────────────────────────────────┘

Time: T=1 (after database ready)
┌─────────────────────────────────────────────────────────────┐
│  Sync Wave 1: Backend                                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application: backend                                 │   │
│  │  Status: Syncing...                                   │   │
│  │                                                       │   │
│  │  1. Create namespace "backend"                       │   │
│  │  2. Create ConfigMap (env vars)                      │   │
│  │  3. Read Secret "database" (password) ✅             │   │
│  │  4. Deploy backend pods                              │   │
│  │  5. Connect to database (DB_HOST=database)           │   │
│  │  6. Wait for pods Ready                              │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│                         │ Status: Healthy ✅                 │
│                         ▼                                    │
└─────────────────────────────────────────────────────────────┘

Time: T=2 (after backend ready)
┌─────────────────────────────────────────────────────────────┐
│  Sync Wave 2: Frontend                                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application: frontend                                │   │
│  │  Status: Syncing...                                   │   │
│  │                                                       │   │
│  │  1. Create namespace "frontend"                      │   │
│  │  2. Create ConfigMap (API_URL=backend)               │   │
│  │  3. Deploy frontend pods                             │   │
│  │  4. Connect to backend service                       │   │
│  │  5. Wait for pods Ready                              │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│                         │ Status: Healthy ✅                 │
│                         ▼                                    │
└─────────────────────────────────────────────────────────────┘

All apps Synced & Healthy! 🎉
```

---

## Why Sync Waves Matter

### Without Sync Waves (All deploy simultaneously)

```
❌ PROBLEM:

T=0: All apps start deploying at same time
├── Database: Starting... (not ready)
├── Backend: Starting... connects to database → FAILS (database not ready)
└── Frontend: Starting... connects to backend → FAILS (backend crashed)

Result: Backend crashes, frontend fails, manual intervention needed
```

### With Sync Waves (Sequential deployment)

```
✅ SOLUTION:

T=0: Database (wave 0) deploys first
     └─> Waits until Healthy ✅

T=1: Backend (wave 1) deploys
     └─> Database already ready ✅
     └─> Connection succeeds ✅

T=2: Frontend (wave 2) deploys
     └─> Backend already ready ✅
     └─> API calls work ✅

Result: Clean deployment, no failures!
```

---

## Application Manifest Structure

### Database Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: database
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # ← Deploy FIRST
spec:
  project: default
  source:
    repoURL: git@github.com:galihhhp/argocd-aws-helm.git
    targetRevision: main
    path: apps/database  # ← Points to Helm chart
  destination:
    server: https://kubernetes.default.svc
    namespace: database
  syncPolicy:
    automated:
      prune: true      # ← Delete removed resources
      selfHeal: true   # ← Fix manual changes
    syncOptions:
      - CreateNamespace=true
```

### Backend Application

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # ← Deploy AFTER database
```

### Frontend Application

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # ← Deploy LAST
```

---

## ArgoCD Sync States

```
┌──────────────┐
│ Unknown      │  Initial state, not synced yet
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ OutOfSync    │  Git state ≠ Cluster state (change detected)
└──────┬───────┘
       │
       │ auto-sync triggered (if enabled)
       ▼
┌──────────────┐
│ Syncing      │  Applying changes to cluster
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Synced       │  Git state = Cluster state ✅
└──────────────┘

Health States:
├── Progressing  (pods starting)
├── Degraded     (some pods failed)
├── Suspended    (scaled to 0)
└── Healthy      (all resources ready) ✅
```

---

## Environment-Specific App-of-Apps

### Development Setup

```
app-of-apps-dev.yaml
├── Watches: develop branch
├── Deploys to: development namespaces
└── Creates:
    ├── database (development namespace)
    ├── backend (development namespace)
    └── frontend (development namespace)

Use case:
- Testing new features
- Lower resource limits
- Faster iteration
```

### Production Setup

```
app-of-apps-prod.yaml
├── Watches: main branch
├── Deploys to: production namespaces
└── Creates:
    ├── database (production namespace)
    ├── backend (production namespace)
    └── frontend (production namespace)

Use case:
- Stable releases only
- Higher resource limits
- NetworkPolicies enabled
```

---

## Verification Commands

```bash
# List all applications
kubectl get applications -n argocd

# Check app-of-apps
argocd app get app-of-apps

# Check sync waves
kubectl get applications -n argocd -o yaml | grep sync-wave

# Watch deployment order
kubectl get applications -n argocd -w

# Check app status
argocd app get database
argocd app get backend
argocd app get frontend
```

---

## Summary

**App-of-Apps Pattern:**
- One root app manages all child apps
- Single kubectl apply deploys everything
- Centralized management

**Sync Waves:**
- Control deployment order
- Database → Backend → Frontend
- Prevents dependency failures

**Auto-Sync:**
- Git push triggers deployment
- No manual intervention
- Self-healing on drift
