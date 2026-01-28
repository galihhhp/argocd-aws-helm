#!/bin/bash

set -e

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name 2>/dev/null)
REGION=$(terraform -chdir=terraform output -raw region 2>/dev/null || echo "ap-southeast-1")

[ -z "$CLUSTER_NAME" ] && echo "Error: CLUSTER_NAME not found" && exit 1

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
kubectl get nodes || { echo "Error: Cannot connect to cluster" && exit 1; }

kubectl get namespace argocd || { echo "Error: argocd namespace not found" && exit 1; }

helm list -n argocd | grep -q argocd || { echo "Error: Argo CD Helm release not found" && exit 1; }

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=30s || { echo "Error: Argo CD server not ready" && exit 1; }

kubectl get secret argocd-initial-admin-secret -n argocd || { echo "Error: Admin password secret not found" && exit 1; }

kubectl get svc argocd-server -n argocd || { echo "Error: Argo CD server service not found" && exit 1; }

echo "Validation passed"
