#!/bin/bash

set -e

cd terraform

terraform init
terraform validate
terraform plan -out=tfplan

read -p "Apply? (yes/no): " confirm
[ "$confirm" = "yes" ] || exit 1

terraform apply tfplan
rm tfplan

CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
REGION=$(terraform output -raw region)

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
kubectl get nodes
