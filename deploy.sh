#!/bin/bash
# Local deployment script to deploy to AKS
# Usage: ./deploy.sh [image_tag] [environment]
# Example: ./deploy.sh v1.0.0-abc123f production

set -e

IMAGE_TAG="${1:-latest}"
ENVIRONMENT="${2:-production}"
ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-myacr.azurecr.io}"
IMAGE_NAME="nodejs-hello"
NAMESPACE="bankx-app"
DEPLOYMENT_NAME="nodejs-hello"

echo "🚀 Deploying ${IMAGE_NAME}:${IMAGE_TAG} to AKS (${ENVIRONMENT})"
echo "================================================================"

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Install it first."
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Install it first."
    exit 1
fi

# Get AKS cluster context from environment or ask user
if [ -z "$AKS_CLUSTER_NAME" ]; then
    AKS_CLUSTER_NAME="bankx-aks-prod"
fi

if [ -z "$AKS_RESOURCE_GROUP" ]; then
    AKS_RESOURCE_GROUP="bankx-prod-rg"
fi

echo "📦 Cluster: ${AKS_CLUSTER_NAME}"
echo "📦 Resource Group: ${AKS_RESOURCE_GROUP}"
echo "📦 Namespace: ${NAMESPACE}"
echo ""

# Get AKS credentials
echo "🔐 Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$AKS_RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Create namespace if not exists
echo "📁 Creating namespace if needed..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Build full image URI
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "🐳 Image: ${FULL_IMAGE}"
echo ""

# Replace image tag in deployment manifest
echo "📝 Updating deployment manifest..."
sed "s|IMAGE_TAG|${FULL_IMAGE}|g" k8s/deployment.yaml > k8s/deployment.tmp.yaml

# Apply manifests
echo "📋 Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.tmp.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Cleanup temp file
rm -f k8s/deployment.tmp.yaml

# Wait for rollout
echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/"$DEPLOYMENT_NAME" \
    --namespace="$NAMESPACE" \
    --timeout=5m

echo ""
echo "✅ Deployment successful!"
echo ""
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE" -l app="$IMAGE_NAME"
echo ""
echo "=== Service Info ==="
kubectl get svc "$IMAGE_NAME" -n "$NAMESPACE"
echo ""
echo "=== Recent Logs ==="
kubectl logs -n "$NAMESPACE" -l "app=$IMAGE_NAME" --tail=20 --all-containers=true || true
