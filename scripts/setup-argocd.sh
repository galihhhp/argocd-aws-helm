#!/bin/bash

set -e

ENVIRONMENT=${1:-prod}

if [[ ! "$ENVIRONMENT" =~ ^(prod|dev|staging)$ ]]; then
    echo "Error: Invalid environment '$ENVIRONMENT'. Valid options: prod, dev, staging" >&2
    echo "Usage: $0 [prod|dev|staging]" >&2
    exit 1
fi

CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name 2>/dev/null)
REGION=$(terraform -chdir=terraform output -raw region 2>/dev/null || echo "ap-southeast-1")
GIT_REPO_URL="git@github.com:galihhhp/argocd-aws-helm.git"

[ -z "$CLUSTER_NAME" ] && { echo "Error: CLUSTER_NAME not found. Run terraform apply first." >&2; exit 1; }

echo "Connecting to cluster: $CLUSTER_NAME"
if ! aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"; then
    echo "Error: Failed to update kubeconfig" >&2
    exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Error: Cannot connect to cluster. Verify cluster is running and IAM permissions are correct." >&2
    exit 1
fi

echo "Installing ArgoCD..."
if ! helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null; then
    echo "Helm repo 'argo' already exists, skipping..."
fi

if ! helm repo update; then
    echo "Error: Failed to update Helm repositories" >&2
    exit 1
fi

if [ ! -f "argocd/values-reference.yaml" ]; then
    echo "Creating values-reference.yaml..."
    helm show values argo/argo-cd > argocd/values-reference.yaml 2>/dev/null || true
fi

if [ ! -f "argocd/values.yaml" ]; then
    echo "Error: argocd/values.yaml not found. This file is required for ArgoCD installation." >&2
    exit 1
fi

echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "Installing ArgoCD Helm chart..."
if ! helm upgrade --install argocd argo/argo-cd -n argocd -f argocd/values.yaml; then
    echo "Error: Failed to install ArgoCD" >&2
    exit 1
fi

echo "Waiting for ArgoCD server to be ready (timeout: 300s)..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s; then
    echo "Error: ArgoCD server pod did not become ready within timeout period" >&2
    echo "Check pod status with: kubectl get pods -n argocd" >&2
    exit 1
fi

ARGOCD_PORT=${ARGOCD_PORT:-9443}
PORT_FORWARD_PID=""

cleanup_port_forward() {
    if [ -n "$PORT_FORWARD_PID" ]; then
        echo "Cleaning up port-forward (PID: $PORT_FORWARD_PID)..."
        kill $PORT_FORWARD_PID 2>/dev/null || true
        wait $PORT_FORWARD_PID 2>/dev/null || true
    fi
}

trap cleanup_port_forward EXIT

start_port_forward() {
    if lsof -Pi :$ARGOCD_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Port $ARGOCD_PORT is already in use, skipping port-forward..."
        return 0
    fi
    
    echo "Starting port-forward on port $ARGOCD_PORT..."
    kubectl port-forward svc/argocd-server -n argocd $ARGOCD_PORT:443 >/dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
        echo "Warning: Port-forward process died" >&2
        PORT_FORWARD_PID=""
        return 1
    fi
    
    return 0
}

if command -v argocd &>/dev/null; then
    echo "Retrieving ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -z "$ARGOCD_PASSWORD" ]; then
        echo "Warning: Could not retrieve ArgoCD admin password. Secret may not be ready yet." >&2
    else
        if start_port_forward; then
            echo "Logging in to ArgoCD..."
            if echo "$ARGOCD_PASSWORD" | argocd login localhost:$ARGOCD_PORT --username admin --insecure --grpc-web 2>/dev/null; then
                echo "Successfully logged in to ArgoCD"
            else
                echo "Warning: Failed to login to ArgoCD CLI. You can login manually later." >&2
            fi
        fi
    fi
else
    echo "ArgoCD CLI not found. Skipping CLI login. Install it with: brew install argocd"
fi

SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/argocd-git-key}
SSH_KEY_PATH=$(eval echo "$SSH_KEY_PATH")

if [ -f "$SSH_KEY_PATH" ] && command -v argocd &>/dev/null; then
    if [ -z "$PORT_FORWARD_PID" ] || ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
        if ! start_port_forward; then
            echo "Warning: Could not start port-forward. Skipping Git repository configuration." >&2
        fi
    fi
    
    if argocd account get-user-info >/dev/null 2>&1; then
        echo "Configuring Git repository..."
        kubectl create secret generic git-repo-secret \
            --from-file=sshPrivateKey="$SSH_KEY_PATH" \
            -n argocd \
            --dry-run=client -o yaml | kubectl apply -f -
        kubectl annotate secret git-repo-secret -n argocd argoproj.io/secret-type=repository --overwrite
        
        if argocd repo add "$GIT_REPO_URL" --ssh-private-key-path "$SSH_KEY_PATH" --insecure-skip-server-verification 2>/dev/null; then
            echo "Git repository added successfully"
        else
            echo "Warning: Failed to add Git repository. It may already exist." >&2
        fi
    else
        echo "Warning: Not logged in to ArgoCD. Skipping Git repository configuration." >&2
    fi
elif [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found at $SSH_KEY_PATH. Skipping Git repository configuration."
    echo "To configure later, set SSH_KEY_PATH environment variable and run this script again."
fi

APP_OF_APPS_FILE="argocd/applications/app-of-apps-${ENVIRONMENT}.yaml"

if [ -f "$APP_OF_APPS_FILE" ]; then
    echo "Applying ArgoCD applications for $ENVIRONMENT environment..."
    if kubectl apply -f "$APP_OF_APPS_FILE"; then
        echo "ArgoCD applications for $ENVIRONMENT environment applied successfully"
    else
        echo "Warning: Failed to apply ArgoCD applications. Check the YAML file for errors." >&2
    fi
elif [ -f "argocd/applications/app-of-apps.yaml" ]; then
    echo "Warning: app-of-apps-${ENVIRONMENT}.yaml not found. Falling back to app-of-apps.yaml"
    echo "Applying ArgoCD applications..."
    if kubectl apply -f argocd/applications/app-of-apps.yaml; then
        echo "ArgoCD applications applied successfully"
    else
        echo "Warning: Failed to apply ArgoCD applications. Check the YAML file for errors." >&2
    fi
else
    echo "No app-of-apps file found for $ENVIRONMENT environment. Skipping application deployment."
    echo "Expected file: $APP_OF_APPS_FILE or argocd/applications/app-of-apps.yaml"
fi

cleanup_port_forward

echo ""
echo "=========================================="
echo "Argo CD setup completed successfully!"
echo "=========================================="
echo ""
echo "Environment: $ENVIRONMENT"
echo ""
echo "To access ArgoCD UI:"
echo "  1. Get admin password:"
echo "     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "  2. Port-forward to access UI:"
echo "     kubectl port-forward svc/argocd-server -n argocd 9443:443"
echo ""
echo "  3. Open browser: https://localhost:9443"
echo "     Username: admin"
echo "     Password: (from step 1)"
echo ""
echo "Usage:"
echo "  $0 prod     - Deploy production environment (default)"
echo "  $0 dev      - Deploy development environment"
echo "  $0 staging  - Deploy staging environment"
echo ""
