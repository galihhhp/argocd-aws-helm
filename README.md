# GitOps Delivery with Argo CD on AWS

A complete GitOps implementation demonstrating modern CI/CD workflows using Terraform, EKS, Argo CD, and Git-based release management.

## Overview

This project demonstrates a production-ready GitOps workflow where:

- **Infrastructure as Code**: Terraform provisions EKS cluster and IAM roles
- **GitOps Controller**: Argo CD deployed via Helm manages application deployments
- **Release Management**: Application releases are managed purely through Git branches and tags
- **Automated Sync**: Argo CD automatically syncs applications from Git repositories

## Why GitOps?

- **Declarative**: Everything in Git, version-controlled and auditable
- **Automated**: Git push triggers deployment
- **Rollback**: Git revert = instant rollback
- **Multi-Environment**: Branches = environments

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Git Repository                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   main       │  │   develop    │  │   tags       │      │
│  │  (production)│  │  (staging)   │  │  (releases)  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ Git Push / Tag
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                      Argo CD (EKS)                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application Controller                              │   │
│  │  - Watches Git repositories                          │   │
│  │  - Compares desired vs actual state                  │   │
│  │  - Auto-syncs applications                           │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application Sync Waves                              │   │
│  │  1. Database (wave 0)                                │   │
│  │  2. Backend API (wave 1)                             │   │
│  │  3. Frontend (wave 2)                                │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ Deploys
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster (AWS)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Frontend    │  │   Backend    │  │  PostgreSQL  │      │
│  │  Pods        │  │   Pods       │  │  Pods        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Repository Structure

```text
argocd-aws/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Provider configuration
│   ├── eks.tf                    # EKS cluster configuration
│   ├── variables.tf              # Terraform variables
│   ├── outputs.tf                # Terraform outputs
│   ├── iam.tf                    # IAM roles and policies
│   └── vpc.tf                    # VPC and networking
│
├── argocd/                       # Argo CD Helm chart configuration
│   ├── values.yaml               # Argo CD Helm values
│   ├── values-reference.yaml     # Reference values from chart
│   └── applications/             # Argo CD Application manifests
│       ├── app-of-apps-dev.yaml  # Root application (development)
│       ├── app-of-apps-prod.yaml # Root application (production)
│       ├── frontend.yaml         # Frontend application
│       ├── backend.yaml          # Backend application
│       └── database.yaml         # Database application
│
├── apps/                         # Application Helm charts (GitOps repo)
│   ├── frontend/                 # Frontend Helm chart (separate chart)
│   │   ├── Chart.yaml            # Frontend chart metadata
│   │   ├── values.yaml           # Default values for frontend
│   │   ├── values-dev.yaml       # Development values
│   │   ├── values-prod.yaml      # Production values
│   │   └── templates/            # Frontend templates
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── configmap.yaml
│   │       ├── serviceaccount.yaml
│   │       └── networkpolicy.yaml
│   ├── backend/                  # Backend Helm chart (separate chart)
│   │   ├── Chart.yaml            # Backend chart metadata
│   │   ├── values.yaml           # Default values for backend
│   │   ├── values-dev.yaml       # Development values
│   │   ├── values-prod.yaml      # Production values
│   │   └── templates/            # Backend templates
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── configmap.yaml
│   │       ├── serviceaccount.yaml
│   │       └── networkpolicy.yaml
│   └── database/                 # Database Helm chart (Bitnami PostgreSQL)
│       ├── Chart.yaml            # Database chart metadata (with Bitnami dependency)
│       ├── Chart.lock            # Dependency lock file
│       ├── values.yaml           # Default values for database
│       ├── values-dev.yaml       # Development values
│       ├── values-prod.yaml      # Production values
│       └── templates/            # Database templates
│           └── _helpers.tpl      # Helper templates
│
├── scripts/                      # Automation scripts
│   ├── setup-infra.sh           # Provision infrastructure via Terraform
│   └── cleanup.sh               # Cleanup all resources
│
├── setup-argocd.sh              # Main script: Deploy Argo CD + Applications
├── validate-argocd.sh           # Validate Argo CD installation
│
└── README.md                     # This file
```

**Note on Database Implementation:**
- Uses Bitnami PostgreSQL Helm chart as a dependency (production-grade)
- No custom StatefulSet templates needed (Bitnami provides everything)
- Secret management handled by Bitnami chart

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- kubectl >= 1.19
- Helm >= 3.0
- Git
- jq (for JSON processing in scripts)
- ArgoCD CLI (optional, for CLI-based management)

## Automation Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/setup-infra.sh` | Provision infrastructure (Terraform) |
| `./setup-argocd.sh [env]` | Deploy ArgoCD + apps (dev/prod) |
| `./validate-argocd.sh` | Validate installation |
| `./scripts/cleanup.sh` | Teardown everything |

## Quick Start

```bash
# 1. Provision infrastructure
./scripts/setup-infra.sh

# 2. Deploy ArgoCD + applications
./setup-argocd.sh dev    # or: prod

# 3. Validate
./validate-argocd.sh

# 4. Access UI
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd 9443:443
# Open: https://localhost:9443 (admin / password-from-above)
```

### Environments

| Environment | Branch | App-of-Apps | Resources |
|------------|--------|-------------|-----------|
| **Dev** | `develop` | `app-of-apps-dev.yaml` | Lower limits |
| **Prod** | `main` | `app-of-apps-prod.yaml` | Higher limits + NetworkPolicies |

## GitOps Workflow

**Deploy to Dev:**
```bash
git checkout develop
# Edit values.yaml
git commit -m "Update version"
git push
# ArgoCD auto-syncs
```

**Promote to Prod:**
```bash
git checkout main
git merge develop
git push
# ArgoCD auto-syncs
```

**Rollback:**
```bash
git revert HEAD
git push
# ArgoCD auto-syncs rollback
```

## Verification

```bash
# Check applications
kubectl get applications -n argocd
argocd app get <app-name>

# Check pods
kubectl get pods -n <namespace>
kubectl logs -n <namespace> <pod-name>

# Sync waves (database→backend→frontend)
kubectl get applications -n argocd -w
```

## Key Concepts

**App-of-Apps Pattern:**
- Root application manages all other applications
- See `argocd/applications/app-of-apps-*.yaml`

**Separate Helm Charts:**
- Each app (frontend, backend, database) = independent chart
- Independent versioning, deployment, rollback
- Database uses Bitnami PostgreSQL (production-grade)

**Sync Waves:**
- Database (wave 0) → Backend (wave 1) → Frontend (wave 2)
- Ensures correct deployment order

**Auto-Sync:**
- Git push → ArgoCD detects → Auto-deploy
- Configured in each application manifest

## Troubleshooting

```bash
# ArgoCD not syncing
kubectl get applications -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
argocd repo list

# Force sync
argocd app sync <app-name> --refresh

# Pod issues
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Cluster access
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

## Best Practices

**Git Strategy:**
- `main` = production
- `develop` = staging/dev
- Use semantic versioning for tags

**Security:**
- Use IAM roles (IRSA)
- Store secrets in AWS Secrets Manager
- Use SSH keys for Git access

## Cleanup

```bash
# Automated
./scripts/cleanup.sh

# Manual
kubectl delete applications --all -n argocd
helm uninstall argocd -n argocd
kubectl delete namespace argocd frontend backend database
cd terraform && terraform destroy
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[MIT](https://opensource.org/licenses/MIT)

## Support

For issues and questions, please open an issue in the repository.
