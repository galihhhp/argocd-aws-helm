# Script Workflow & Execution Order

## Execution Order

```
┌──────────────────────┐
│ 1. setup-infra.sh    │  Creates VPC, EKS cluster, IAM
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 2. setup-argocd.sh   │  Deploys ArgoCD + apps (dev/prod)
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ 3. validate-argocd.sh│  Validates installation
└──────────────────────┘
```

---

## Setup Commands

```bash
./scripts/setup-infra.sh
./setup-argocd.sh dev
./validate-argocd.sh
```

---

## Cleanup Command

```bash
./scripts/cleanup.sh
```

Deletes everything in reverse order:
1. ArgoCD applications
2. ArgoCD installation
3. Namespaces
4. Infrastructure (EKS, VPC)

---

## Environment Selection

```bash
./setup-argocd.sh dev   # Development (develop branch)
./setup-argocd.sh prod  # Production (main branch)
./setup-argocd.sh       # Default: prod
```
