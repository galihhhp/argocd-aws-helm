# Terraform Infrastructure Architecture

This diagram shows the complete AWS infrastructure created by Terraform, including VPC, subnets, NAT, EKS, and IAM.

## Complete Infrastructure Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AWS ACCOUNT                                      │
│                       Region: ap-southeast-1                              │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Internet Gateway (IGW)                                           │  │
│  │  - Allows internet access for public subnet                       │  │
│  └────────────────────────────┬──────────────────────────────────────┘  │
│                               │                                          │
│  ┌────────────────────────────┴──────────────────────────────────────┐  │
│  │                     Public Subnet                                  │  │
│  │                   10.0.1.0/24 (AZ: ap-southeast-1a)                │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │  NAT Gateway                                                   │ │  │
│  │  │  - Bridge for private subnet → internet                       │ │  │
│  │  │  - Has Elastic IP (stable public IP)                          │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  │                                                                     │  │
│  │  Route Table (Public):                                             │  │
│  │    0.0.0.0/0 → Internet Gateway                                    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                               │                                          │
│                               │ NAT Gateway routes traffic               │
│                               ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                     Private Subnet                                  │  │
│  │                   10.0.2.0/24 (AZ: ap-southeast-1b)                │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │  EKS Cluster: argocd-eks-cluster                             │ │  │
│  │  │  Version: 1.31                                                │ │  │
│  │  │                                                               │ │  │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  EKS Node Group                                        │ │ │  │
│  │  │  │  Instance Type: t3.medium                              │ │ │  │
│  │  │  │  Min: 1, Max: 2, Desired: 1                            │ │ │  │
│  │  │  │                                                         │ │ │  │
│  │  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐│ │ │  │
│  │  │  │  │  ArgoCD      │  │  Frontend    │  │  Backend     ││ │ │  │
│  │  │  │  │  Pods        │  │  Pods        │  │  Pods        ││ │ │  │
│  │  │  │  └──────────────┘  └──────────────┘  └──────────────┘│ │ │  │
│  │  │  │  ┌──────────────┐                                     │ │ │  │
│  │  │  │  │  Database    │                                     │ │ │  │
│  │  │  │  │  Pods        │                                     │ │ │  │
│  │  │  │  └──────────────┘                                     │ │ │  │
│  │  │  └────────────────────────────────────────────────────────┘ │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  │                                                                     │  │
│  │  Route Table (Private):                                            │  │
│  │    0.0.0.0/0 → NAT Gateway                                         │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## IAM Roles & Policies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          IAM CONFIGURATION                                │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────┐
│  EKS Cluster Role                    │
│  Name: argocd-eks-cluster-role       │
│                                      │
│  Trust Policy:                       │
│    Principal: eks.amazonaws.com      │
│    Action: sts:AssumeRole            │
│                                      │
│  Attached Policies:                  │
│    • AmazonEKSClusterPolicy          │
│    • AmazonEKSVPCResourceController  │
└────────────┬─────────────────────────┘
             │
             │ Used by
             ▼
┌──────────────────────────────────────┐
│  EKS Cluster                         │
│  - Manage cluster lifecycle          │
│  - Control plane operations          │
│  - API server                        │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  EKS Node Group Role                 │
│  Name: argocd-eks-node-group         │
│                                      │
│  Trust Policy:                       │
│    Principal: ec2.amazonaws.com      │
│    Action: sts:AssumeRole            │
│                                      │
│  Attached Policies:                  │
│    • AmazonEKSWorkerNodePolicy       │
│    • AmazonEKS_CNI_Policy            │
│    • AmazonEC2ContainerRegistryReadOnly│
│    • AmazonEKSVPCResourceController  │
└────────────┬─────────────────────────┘
             │
             │ Used by
             ▼
┌──────────────────────────────────────┐
│  Worker Nodes (EC2)                  │
│  - Pull container images (ECR)       │
│  - Join cluster                      │
│  - Run pods                          │
│  - Configure networking (CNI)        │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│  EKS Access Entry                    │
│  Principal: Current IAM User         │
│                                      │
│  Access Policy:                      │
│    AmazonEKSClusterAdminPolicy       │
│                                      │
│  Scope: Cluster                      │
└────────────┬─────────────────────────┘
             │
             │ Allows
             ▼
┌──────────────────────────────────────┐
│  kubectl Access                      │
│  - Full cluster admin access         │
│  - Create/delete resources           │
│  - View logs & metrics               │
└──────────────────────────────────────┘
```

---

## Network Flow Diagrams

### Internet Access Flow (Pods → Internet)

```
┌──────────────┐
│ Pod in EKS   │ (e.g., need to pull Docker image)
│ Private IP   │
└──────┬───────┘
       │
       │ 1. Pod wants internet access
       ▼
┌──────────────────────┐
│ Private Subnet       │
│ Route Table:         │
│ 0.0.0.0/0 → NAT GW   │ ← Routes all internet traffic to NAT
└──────┬───────────────┘
       │
       │ 2. Routed to NAT Gateway
       ▼
┌──────────────────────┐
│ NAT Gateway          │
│ (in Public Subnet)   │
│ Has Elastic IP       │ ← Source NAT translation
└──────┬───────────────┘
       │
       │ 3. Translated to public IP
       ▼
┌──────────────────────┐
│ Internet Gateway     │
│ (IGW)                │
└──────┬───────────────┘
       │
       │ 4. Out to internet
       ▼
┌──────────────────────┐
│ Internet             │
│ (Docker Hub, etc.)   │
└──────────────────────┘
```

### kubectl Access Flow (Local → EKS)

```
┌──────────────┐
│ Local Machine│
│ (Developer)  │
└──────┬───────┘
       │
       │ 1. kubectl command
       ▼
┌──────────────────────┐
│ AWS IAM              │
│ Authenticates:       │
│ - User ARN           │
│ - Access Key         │
└──────┬───────────────┘
       │
       │ 2. IAM validates
       ▼
┌──────────────────────┐
│ EKS Access Entry     │
│ Checks:              │
│ - Principal ARN      │
│ - Cluster Admin Policy│
└──────┬───────────────┘
       │
       │ 3. Authorized ✅
       ▼
┌──────────────────────┐
│ EKS API Server       │
│ (Public Endpoint)    │
└──────┬───────────────┘
       │
       │ 4. Execute command
       ▼
┌──────────────────────┐
│ Kubernetes Cluster   │
│ - Get/Create resources│
│ - View logs          │
└──────────────────────┘
```

---

## Terraform Resource Dependencies

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Terraform Apply Order                             │
└─────────────────────────────────────────────────────────────────────┘

1. VPC Resources (No dependencies)
   ┌──────────────┐
   │ VPC          │
   │ CIDR Block   │
   └──────┬───────┘
          │
          ├──> Internet Gateway
          │
          ├──> Public Subnet
          │
          └──> Private Subnet

2. NAT & Routing (Depends on #1)
   ┌──────────────┐
   │ Elastic IP   │ (depends: Internet Gateway)
   └──────┬───────┘
          │
          ▼
   ┌──────────────┐
   │ NAT Gateway  │ (depends: Elastic IP, Public Subnet)
   └──────┬───────┘
          │
          ├──> Public Route Table
          └──> Private Route Table

3. IAM Roles (No dependencies)
   ┌──────────────────┐
   │ EKS Cluster Role │
   └──────────────────┘
   ┌──────────────────┐
   │ EKS Node Role    │
   └──────────────────┘

4. EKS Cluster (Depends on #1, #2, #3)
   ┌──────────────────┐
   │ EKS Cluster      │ (depends: VPC, Subnets, IAM Role)
   └──────┬───────────┘
          │
          ▼
5. EKS Node Group (Depends on #4)
   ┌──────────────────┐
   │ Node Group       │ (depends: EKS Cluster, Node Role)
   └──────────────────┘

6. EKS Access (Depends on #4)
   ┌──────────────────┐
   │ Access Entry     │ (depends: EKS Cluster)
   └──────────────────┘
```

---

## Key Networking Concepts

### Why NAT Gateway?

```
Problem: Pods need internet access but should NOT have public IPs

Without NAT:
  Pod (private IP) ──X──> Internet
  ❌ Can't reach internet
  ❌ Can't pull Docker images
  ❌ Can't call external APIs

With NAT:
  Pod (10.0.2.x) ──> NAT Gateway ──> Internet
                     (translates to public IP)
  ✅ Can reach internet
  ✅ Can pull images
  ✅ External services see NAT's public IP, not pod IP
```

### Why Public + Private Subnets?

```
Public Subnet (10.0.1.0/24):
  ├─ Has route to Internet Gateway
  ├─ Resources get public IPs
  ├─ Hosts: NAT Gateway
  └─ Purpose: Internet-facing resources

Private Subnet (10.0.2.0/24):
  ├─ Route to NAT Gateway (not direct internet)
  ├─ No public IPs
  ├─ Hosts: EKS Nodes, Pods
  └─ Purpose: Internal resources (better security)

Benefits:
  ✅ Pods not directly exposed to internet
  ✅ Attack surface reduced
  ✅ Controlled egress via NAT
```

---

## Terraform Files Breakdown

### `vpc.tf` - Networking Resources

```
Creates:
├── VPC (10.0.0.0/16)
├── Internet Gateway
├── Public Subnet (10.0.1.0/24)
├── Private Subnet (10.0.2.0/24)
├── Elastic IP
├── NAT Gateway
├── Route Table (Public)
└── Route Table (Private)

Purpose: Complete network infrastructure for EKS
```

### `eks.tf` - EKS Resources

```
Creates:
├── EKS Cluster
│   ├── Version: 1.31
│   ├── VPC Config: Public + Private subnets
│   └── Role: eks-cluster-role
└── EKS Node Group
    ├── Instance Type: t3.medium
    ├── Capacity: min=1, max=2, desired=1
    ├── Subnets: Private only
    └── Role: eks-node-group-role

Purpose: Kubernetes cluster infrastructure
```

### `iam.tf` - IAM Resources

```
Creates:
├── EKS Cluster Role
│   ├── Trust Policy: eks.amazonaws.com
│   └── Policies: EKS Cluster, VPC Controller
├── EKS Node Role
│   ├── Trust Policy: ec2.amazonaws.com
│   └── Policies: Worker Node, CNI, ECR
└── EKS Access Entry
    ├── Principal: Current IAM user
    └── Policy: Cluster Admin

Purpose: Permissions for cluster and nodes
```

### `main.tf` - Provider Config

```
Configures:
├── AWS Provider
│   └── Region: ap-southeast-1
├── Terraform Version
└── Required Providers

Purpose: Terraform & AWS configuration
```

### `variables.tf` - Input Variables

```
Defines:
├── name_prefix (default: "argocd")
├── region (default: "ap-southeast-1")
├── vpc_cidr (default: "10.0.0.0/16")
├── public_subnet_cidr
├── private_subnet_cidr
├── node_instance_type
└── eks_access_entries

Purpose: Customizable configuration
```

### `outputs.tf` - Outputs

```
Exports:
├── eks_cluster_name
├── eks_cluster_endpoint
├── region
├── vpc_id
└── kubeconfig_command

Purpose: Information for other tools (kubectl, scripts)
```

---

## Common Questions

### Q: Why are pods in private subnet?
**A:** Security. Pods don't get public IPs, reducing attack surface. They access internet via NAT.

### Q: Can I SSH into nodes?
**A:** No direct SSH by default (private subnet). Use AWS Systems Manager Session Manager if needed.

### Q: What if NAT Gateway fails?
**A:** Pods lose internet access (can't pull images). NAT Gateway is HA within one AZ. For multi-AZ, need multiple NATs.

### Q: How much does NAT Gateway cost?
**A:** ~$0.045/hour + $0.045/GB processed. Can be expensive with high traffic. Alternative: NAT Instance (cheaper but less reliable).

### Q: Why t3.medium for nodes?
**A:** Balance of cost vs performance. ArgoCD + 3 apps fits comfortably. Scale up for production.

---

## Cost Breakdown (Estimated)

```
Monthly costs (ap-southeast-1):

EKS Cluster:          $73/month (fixed)
t3.medium nodes:      ~$30/month (1 node)
NAT Gateway:          ~$33/month + data transfer
Elastic IP:           Free (attached to NAT)
VPC/Subnets:          Free

Total: ~$136-150/month (excluding data transfer)
```

---

## Summary

**Terraform creates:**
1. ✅ VPC with public/private subnets
2. ✅ NAT Gateway for private subnet internet access
3. ✅ EKS Cluster with 1 node
4. ✅ IAM roles for cluster & nodes
5. ✅ Access entry for kubectl access

**Result:** Secure, production-ready Kubernetes cluster on AWS.
