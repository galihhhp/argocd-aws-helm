# GitOps Delivery with Argo CD on AWS

A complete GitOps implementation demonstrating modern CI/CD workflows using Terraform, EKS, Argo CD, and Git-based release management.

## Overview

This project demonstrates a production-ready GitOps workflow where:

- **Infrastructure as Code**: Terraform provisions EKS cluster and IAM roles
- **GitOps Controller**: Argo CD deployed via Helm manages application deployments
- **Release Management**: Application releases are managed purely through Git branches and tags
- **Automated Sync**: Argo CD automatically syncs applications from Git repositories

## Why GitOps?

GitOps provides several advantages over traditional deployment methods:

- **Declarative**: Desired state is defined in Git, making it version-controlled and auditable
- **Automated**: Changes in Git automatically trigger deployments
- **Rollback**: Simple Git revert enables instant rollback to previous versions
- **Multi-Environment**: Manage multiple environments (dev, staging, prod) through Git branches
- **Collaboration**: Standard Git workflows (PRs, reviews) apply to infrastructure and deployments

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
│   ├── main.tf                   # EKS cluster configuration
│   ├── variables.tf              # Terraform variables
│   ├── outputs.tf                # Terraform outputs
│   ├── iam.tf                    # IAM roles and policies
│   └── vpc.tf                    # VPC and networking
│
├── argocd/                       # Argo CD Helm chart configuration
│   ├── values.yaml               # Argo CD Helm values
│   └── applications/             # Argo CD Application manifests
│       ├── app-of-apps.yaml      # Root application
│       ├── frontend.yaml         # Frontend application
│       ├── backend.yaml          # Backend application
│       └── database.yaml         # Database application
│
├── apps/                         # Application Helm charts (GitOps repo)
│   ├── frontend/                 # Frontend Helm chart (separate chart)
│   │   ├── Chart.yaml            # Frontend chart metadata
│   │   ├── values.yaml           # Default values for frontend
│   │   ├── values-dev.yaml       # Development values (optional)
│   │   ├── values-prod.yaml      # Production values (optional)
│   │   └── templates/            # Frontend templates
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── backend/                  # Backend Helm chart (separate chart)
│   │   ├── Chart.yaml            # Backend chart metadata
│   │   ├── values.yaml           # Default values for backend
│   │   ├── values-dev.yaml       # Development values (optional)
│   │   ├── values-prod.yaml      # Production values (optional)
│   │   └── templates/            # Backend templates
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   └── database/                 # Database Helm chart (separate chart)
│       ├── Chart.yaml            # Database chart metadata
│       ├── values.yaml           # Default values for database
│       ├── values-dev.yaml       # Development values (optional)
│       ├── values-prod.yaml      # Production values (optional)
│       └── templates/            # Database templates
│           └── statefulset.yaml
│
├── scripts/                      # Automation scripts
│   ├── setup-infra.sh           # Provision infrastructure
│   ├── deploy-argocd.sh         # Deploy Argo CD
│   ├── setup-apps.sh            # Configure Argo CD applications
│   └── cleanup.sh               # Cleanup resources
│
└── README.md                     # This file
```

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- kubectl >= 1.19
- Helm >= 3.0
- Git
- jq (for JSON processing in scripts)

## Quick Start

### 1. Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates:
- EKS cluster
- VPC and networking components
- IAM roles for EKS and Argo CD
- Security groups

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl get nodes
```

### 3. Deploy Argo CD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd/values.yaml
```

### 4. Access Argo CD UI

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Port-forward to access UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: `https://localhost:8080`
- Username: `admin`
- Password: (from command above)

### 5. Configure Git Repository Access

Argo CD needs access to your Git repository. Configure using one of:

**Option A: SSH Key (Recommended)**

```bash
kubectl create secret generic git-repo-secret \
  --from-file=ssh-privatekey=<path-to-private-key> \
  -n argocd
```

**Option B: HTTPS with Token**

```bash
kubectl create secret generic git-repo-secret \
  --from-literal=username=<git-username> \
  --from-literal=password=<git-token> \
  -n argocd
```

### 6. Deploy Applications via Argo CD

```bash
kubectl apply -f argocd/applications/app-of-apps.yaml
```

This creates the root application that manages all other applications.

## GitOps Workflow

### Managing Releases via Git Branches

**Development Environment:**
```bash
git checkout develop
git pull origin develop
# Make changes to manifests
git commit -m "Update app version to 1.2.0"
git push origin develop
# Argo CD auto-syncs develop branch
```

**Production Environment:**
```bash
git checkout main
git merge develop
git push origin main
# Argo CD auto-syncs main branch
```

### Managing Releases via Git Tags

**Create a Release:**
```bash
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

**Configure Argo CD Application to use tags:**

```yaml
spec:
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: v1.2.0  # Use tag instead of branch
```

### Rollback via Git Revert

**Rollback to Previous Version:**
```bash
git revert HEAD
git push origin main
# Argo CD detects change and rolls back automatically
```

**Or Rollback to Specific Commit:**
```bash
git revert <commit-hash>
git push origin main
```

## Testing & QA

### Validate Auto-Sync from Git

1. **Make a change to Helm chart values or templates in Git**
2. **Push to repository**
3. **Verify Argo CD detects the change:**

```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

4. **Check sync status in Argo CD UI or CLI:**

```bash
argocd app get <app-name>
```

5. **Verify application deployed:**

```bash
kubectl get pods -n <app-namespace>
kubectl logs -n <app-namespace> <pod-name>
```

### Test Rollback via Git Revert

1. **Identify the commit to rollback to:**
```bash
git log --oneline
```

2. **Revert the commit:**
```bash
git revert <commit-hash>
git push origin main
```

3. **Verify Argo CD syncs the rollback:**
```bash
argocd app sync <app-name>
argocd app wait <app-name>
```

4. **Confirm application state matches previous version:**
```bash
kubectl get deployment <app-name> -n <app-namespace> -o yaml
```

### Test Multi-App Sync Waves

Sync waves ensure applications deploy in the correct order:

**Example sync wave configuration:**

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Database deploys first
```

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Backend deploys second
```

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"  # Frontend deploys last
```

**Test sync waves:**

1. **Deploy all applications simultaneously**
2. **Monitor sync order:**

```bash
kubectl get applications -n argocd -w
```

3. **Verify deployment order:**
   - Database pods should be `Running` first
   - Backend pods should start after database is ready
   - Frontend pods should start after backend is ready

## Configuration

### Argo CD Application Configuration

**Application of Applications Pattern:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: argocd/applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Individual Application (Helm Chart):**

Each application references its own chart. You can use different values files per environment:

**Development Environment:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: develop
    path: apps/frontend
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml  # Override with dev values
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-dev
```

**Production Environment:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: apps/frontend
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml  # Override with prod values
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-prod
```

**Note:** Each app (frontend, backend, database) has its own chart and can be deployed independently.

### Helm Chart Configuration

Argo CD applications use Helm charts stored in Git. Each application references a Helm chart:

**Why `templates/` folder is required:**

Helm charts use a templating system where:
- `values.yaml` = **Data/Configuration** (what values to use)
- `templates/` = **Template files** (Kubernetes manifests with placeholders)
- Helm combines them to generate final Kubernetes manifests

**How it works:**
1. Templates contain Kubernetes manifests with Go template syntax (e.g., `{{ .Values.replicaCount }}`)
2. Helm reads `values.yaml` and renders templates
3. Final rendered manifests are applied to Kubernetes cluster

**Helm Source Configuration:**
```yaml
spec:
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: apps/frontend
    helm:
      valueFiles:
        - values.yaml
      values: |
        replicaCount: 3
        image:
          tag: "1.2.0"
```

**Helm Chart Structure (Each app has its own chart):**

Each application (frontend, backend, database) has a **separate Helm chart**:

```text
apps/frontend/          # Frontend chart (independent)
├── Chart.yaml          # Frontend chart metadata
├── values.yaml         # Default values for frontend
├── values-dev.yaml     # Dev environment values (optional)
├── values-prod.yaml    # Prod environment values (optional)
└── templates/         # Frontend templates
    ├── deployment.yaml
    └── service.yaml

apps/backend/           # Backend chart (independent)
├── Chart.yaml          # Backend chart metadata
├── values.yaml         # Default values for backend
└── templates/         # Backend templates
    ├── deployment.yaml
    └── service.yaml

apps/database/          # Database chart (independent)
├── Chart.yaml          # Database chart metadata
├── values.yaml         # Default values for database
└── templates/         # Database templates
    └── statefulset.yaml
```

**Why separate charts vs one combined chart?**

**Separate Charts (Recommended for GitOps):**
- ✅ **Independent versioning**: Frontend v1.2.0, Backend v2.0.0, Database v1.0.0
- ✅ **Independent deployment**: Update frontend without affecting backend/database
- ✅ **Independent rollback**: Rollback frontend without rolling back backend
- ✅ **Team ownership**: Frontend team, Backend team, Database team manage their own charts
- ✅ **Independent scaling**: Scale frontend replicas without scaling backend
- ✅ **Selective updates**: Update only what changed (e.g., only frontend image tag)
- ✅ **GitOps friendly**: Each app can sync from different Git branches/tags
- ✅ **Resource isolation**: Each app has its own namespace and resources

**One Combined Chart (Alternative approach):**
- ⚠️ **Tightly coupled**: All apps deploy/update/rollback together
- ⚠️ **Single version**: All apps share same chart version
- ⚠️ **All-or-nothing**: Can't update just one component
- ✅ **Simpler**: One chart to manage, one values file
- ✅ **Atomic deployment**: All components deploy together (good for tightly coupled apps)

**When to use separate charts (our approach):**
- Microservices architecture (frontend, backend, database are separate services)
- Different teams own different components
- Need independent release cycles
- GitOps workflow where each app syncs independently

**When to use one combined chart:**
- Monolithic application where components are tightly coupled
- Single team owns everything
- Components must always deploy together
- Simple application with few components

**Example: One Combined Chart Structure (Alternative):**
```text
apps/fullstack-app/      # One chart for everything
├── Chart.yaml
├── values.yaml          # Single values file for all components
│   ├── frontend:
│   │   ├── replicaCount: 3
│   │   └── image: ...
│   ├── backend:
│   │   ├── replicaCount: 2
│   │   └── image: ...
│   └── database:
│       ├── storage: 20Gi
│       └── ...
└── templates/
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── backend-deployment.yaml
    ├── backend-service.yaml
    └── database-statefulset.yaml
```

**Our Recommendation:**
For GitOps with Argo CD, **separate charts are preferred** because:
- Argo CD can sync each app independently from different Git branches/tags
- You can update frontend from `develop` branch while backend stays on `main`
- Better alignment with microservices architecture
- More flexible for multi-team environments

**Example template file (`templates/deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
```

**Corresponding `values.yaml`:**
```yaml
name: frontend
replicaCount: 3
image:
  repository: nginx
  tag: "1.21"
```

When Helm renders this, it replaces `{{ .Values.replicaCount }}` with `3`, `{{ .Values.image.tag }}` with `"1.21"`, etc.

### Sync Policies

**Manual Sync (Recommended for Production):**
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

**Automatic Sync:**
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

**Sync Windows (Deploy only during business hours):**
```yaml
syncPolicy:
  syncWindows:
    - kind: allow
      schedule: '10 9 * * *'
      duration: 8h
      applications:
        - '*'
```

## Troubleshooting

### Argo CD Not Syncing

**Check application status:**
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

**Check Argo CD controller logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Verify Git repository access:**
```bash
kubectl get secrets -n argocd
argocd repo list
```

### Application Stuck in Syncing State

**Force refresh:**
```bash
argocd app get <app-name> --refresh
```

**Manual sync:**
```bash
argocd app sync <app-name>
```

**Check for sync errors:**
```bash
argocd app get <app-name> --show-operation
```

### Git Authentication Issues

**Test repository access:**
```bash
argocd repo test <repo-url>
```

**Update repository credentials:**
```bash
argocd repo add <repo-url> --username <username> --password <password>
```

### EKS Cluster Access Issues

**Verify kubectl context:**
```bash
kubectl config current-context
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

**Check IAM roles:**
```bash
aws iam get-role --role-name <eks-cluster-role>
aws iam get-role --role-name <eks-node-role>
```

### Application Deployment Failures

**Check pod status:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Check events:**
```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Best Practices

### Git Branching Strategy

- **main**: Production environment
- **develop**: Development/staging environment
- **feature/***: Feature branches for testing

### Tagging Strategy

- Use semantic versioning: `v1.2.3`
- Tag releases: `git tag -a v1.2.0 -m "Release 1.2.0"`
- Tag hotfixes: `git tag -a v1.2.1 -m "Hotfix 1.2.1"`

### Security

- Use IAM roles for service accounts (IRSA) for AWS resource access
- Store secrets in AWS Secrets Manager or external secret operators
- Enable RBAC in Argo CD
- Use Git SSH keys instead of HTTPS tokens when possible
- Enable audit logging for Argo CD

### Monitoring

- Set up Prometheus metrics for Argo CD
- Monitor application sync status
- Alert on sync failures
- Track deployment frequency and lead time

## Cleanup

### Remove Applications

```bash
kubectl delete application <app-name> -n argocd
```

### Uninstall Argo CD

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
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
