#!/bin/bash

set -e

read -p "Destroy everything? (yes/no): " confirm
[ "$confirm" = "yes" ] || exit 1

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ]; then
    REGION=$(terraform -chdir=terraform output -raw region)
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || true
    
    kubectl delete applications --all -n argocd --timeout=60s 2>/dev/null || true
    helm uninstall argocd -n argocd 2>/dev/null || true
    kubectl delete namespace argocd frontend backend database --timeout=60s 2>/dev/null || true
fi

cd terraform
terraform destroy -auto-approve
