# Complete GitOps Flow

This diagram shows the end-to-end GitOps workflow from developer action to Kubernetes deployment.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                                    │
│  ┌──────────────┐                                                    │
│  │ Local Code   │                                                    │
│  │ Changes      │                                                    │
│  └──────┬───────┘                                                    │
│         │                                                            │
│         │ git commit & push                                          │
│         ▼                                                            │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ Git Repository (GitHub/GitLab)                           │       │
│  │                                                          │       │
│  │  apps/frontend/values.yaml                               │       │
│  │    image:                                                │       │
│  │      tag: "2.0.0" → "2.0.1"  ← Changed!                │       │
│  │                                                          │       │
│  │  Branch: develop (dev env) or main (prod env)           │       │
│  └──────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             │ ArgoCD watches Git repo
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ARGOCD (in EKS)                                   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  ArgoCD Application Controller                              │   │
│  │                                                              │   │
│  │  1. Polls Git every 3 minutes (or webhook)                  │   │
│  │  2. Detects: "values.yaml changed!"                         │   │
│  │  3. Compares: Git state vs Cluster state                    │   │
│  │  4. Status: "OutOfSync" → "Syncing"                         │   │
│  │                                                              │   │
│  │  Sync Policy:                                               │   │
│  │    automated:                                               │   │
│  │      prune: true        ← Delete removed resources          │   │
│  │      selfHeal: true     ← Auto-fix manual changes           │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                             │                                       │
│                             │ Apply changes                         │
│                             ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Sync Waves (Ordered Deployment)                            │   │
│  │                                                              │   │
│  │  Wave 0: Database      ──┐                                  │   │
│  │  Wave 1: Backend         │ Deploy in sequence               │   │
│  │  Wave 2: Frontend      ──┘                                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             │ Kubernetes API
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EKS CLUSTER (AWS)                                 │
│                                                                      │
│  Namespace: frontend                                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Deployment: frontend                                         │   │
│  │   Old: image: galihhhp/react-frontend:2.0.0                  │   │
│  │   New: image: galihhhp/react-frontend:2.0.1  ← Updated!     │   │
│  │                                                              │   │
│  │   Rolling Update:                                            │   │
│  │   1. Create new pod (2.0.1)                                  │   │
│  │   2. Wait until healthy                                      │   │
│  │   3. Terminate old pod (2.0.0)                               │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  Frontend Pods  │  │  Backend Pods   │  │ Database Pods   │    │
│  │  (2.0.1) ✅     │  │  (unchanged)    │  │ (unchanged)     │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

### **GitOps Principles**

1. **Git as Single Source of Truth**
   - All configuration in Git
   - Git commit = deployment trigger
   - No manual kubectl apply

2. **Declarative**
   - Describe desired state, not steps
   - ArgoCD ensures cluster matches Git

3. **Automated Sync**
   - ArgoCD polls Git (default: 3 min)
   - Auto-detect changes
   - Auto-apply updates

4. **Self-Healing**
   - Detect drift (manual changes)
   - Auto-correct to Git state

---

## Workflow Steps

### **1. Developer Makes Change**
```bash
# Edit Helm values
vim apps/frontend/values.yaml
# Change: tag: "2.0.0" → "2.0.1"

# Commit & push
git commit -m "Update frontend to 2.0.1"
git push origin develop
```

### **2. ArgoCD Detects Change**
```
ArgoCD Controller (polls every 3 min):
  ├─ Compare Git vs Cluster
  ├─ Detect difference: tag changed
  └─ Status: OutOfSync
```

### **3. ArgoCD Syncs**
```
Auto-Sync (if enabled):
  ├─ Generate manifests from Helm chart
  ├─ Apply to Kubernetes
  └─ Status: Syncing → Synced
```

### **4. Kubernetes Deploys**
```
Rolling Update:
  ├─ Create new ReplicaSet (2.0.1)
  ├─ Scale up new pods
  ├─ Wait for readiness
  ├─ Scale down old pods (2.0.0)
  └─ Delete old ReplicaSet
```

---

## Rollback Flow

```
┌──────────────┐
│  Developer   │
│              │
│ git revert   │  ← Revert commit in Git
│ git push     │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  Git Repository      │
│                      │
│  Reverted to:        │
│  tag: "2.0.0"        │  ← Previous version
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  ArgoCD              │
│                      │
│  Detects revert      │
│  Syncs to 2.0.0      │  ← Auto-rollback!
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Kubernetes          │
│                      │
│  Rolling update      │
│  back to 2.0.0       │  ← Rollback complete
└──────────────────────┘
```

**Key Point:** Rollback is just another Git commit. No special commands needed!

---

## Multi-Environment Flow

```
┌─────────────────────────────────────────────────────────┐
│                   Git Repository                         │
│                                                          │
│  Branch: develop          Branch: main                   │
│  ┌──────────────┐        ┌──────────────┐              │
│  │ Dev Config   │        │ Prod Config  │              │
│  │ tag: "2.0.1" │        │ tag: "2.0.0" │              │
│  └──────┬───────┘        └──────┬───────┘              │
│         │                       │                       │
└─────────┼───────────────────────┼───────────────────────┘
          │                       │
          │                       │
          ▼                       ▼
  ┌──────────────┐        ┌──────────────┐
  │ ArgoCD Dev   │        │ ArgoCD Prod  │
  │ app-of-apps- │        │ app-of-apps- │
  │ dev.yaml     │        │ prod.yaml    │
  └──────┬───────┘        └──────┬───────┘
         │                       │
         ▼                       ▼
  ┌──────────────┐        ┌──────────────┐
  │ Dev Cluster  │        │ Prod Cluster │
  │ (testing)    │        │ (stable)     │
  └──────────────┘        └──────────────┘
```

**Promotion Flow:**
```bash
# Test in dev first
git checkout develop
git push

# When ready, promote to prod
git checkout main
git merge develop
git push

# ArgoCD prod automatically syncs!
```

---

## Benefits Visualization

```
Traditional Deployment        GitOps with ArgoCD
───────────────────          ──────────────────

Developer                    Developer
    │                            │
    │ kubectl apply              │ git push
    ▼                            ▼
Kubernetes ❌                 Git Repository ✅
                                 │
Manual, error-prone              │ ArgoCD watches
No audit trail                   ▼
No rollback                   Kubernetes ✅
No consistency                
                              Automated
                              Auditable (Git history)
                              Easy rollback (git revert)
                              Always in sync
```

---

## Common Scenarios

### **Scenario 1: Update Image Version**
```
Change: values.yaml → image.tag: "2.0.1"
Git: commit + push
ArgoCD: Auto-sync in ~3 minutes
Result: New pods deployed
```

### **Scenario 2: Scale Replicas**
```
Change: values.yaml → replicaCount: 3
Git: commit + push
ArgoCD: Auto-sync
Result: 3 pods running
```

### **Scenario 3: Add Environment Variable**
```
Change: values.yaml → env.NEW_VAR: "value"
Git: commit + push
ArgoCD: Auto-sync
Result: Pods restarted with new env
```

### **Scenario 4: Someone Does kubectl apply Manually**
```
Manual: kubectl scale deployment --replicas=5
ArgoCD: Detects drift (Git says 3, cluster has 5)
selfHeal: Auto-scale back to 3
Result: Git state enforced ✅
```

---

## Monitoring the Flow

```bash
# Watch sync status
kubectl get applications -n argocd -w

# Check specific app
argocd app get frontend

# View sync history
argocd app history frontend

# See what changed
argocd app diff frontend
```

---

## Troubleshooting Flow

```
Git Push
   ▼
ArgoCD Not Syncing? ──┐
   │                  │
   NO                 YES → Check sync policy (automated?)
   │                       → Check repo access (credentials?)
   │                       → Force refresh: argocd app sync
   ▼
Syncing but Failed? ──┐
   │                  │
   NO                 YES → Check ArgoCD logs
   │                       → Check resource errors
   │                       → kubectl describe pod
   ▼
Synced but Unhealthy? ─┐
   │                    │
   NO                   YES → Check application logs
   │                         → Check readiness probes
   ▼                         → Check dependencies (DB up?)
All Good! ✅
```

---

## Summary

**GitOps Flow = Git → ArgoCD → Kubernetes**

1. Developer commits to Git
2. ArgoCD detects change
3. ArgoCD syncs to Kubernetes
4. Kubernetes deploys

**Benefits:**
- ✅ Git = single source of truth
- ✅ Automatic deployment
- ✅ Easy rollback (git revert)
- ✅ Audit trail (git log)
- ✅ Multi-environment support
