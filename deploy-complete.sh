#!/bin/bash

# Complete Deployment Script for VariPhi LMS
# This script handles: image build, push, certificate creation, and Helm deployment

set -e

PROJECT_ID="variphi"
CLUSTER_NAME="gke-prod-asia-south1"
REGION="asia-south1"
IMAGE_NAME="variphi/lms-app"
IMAGE_TAG="latest"
REGISTRY="asia-south1-docker.pkg.dev"
REPOSITORY="vgiskill"
IMAGE_PATH="lms-prod"

FULL_IMAGE_NAME="${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_PATH}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=========================================="
echo "VariPhi LMS - Complete Deployment"
echo "=========================================="
echo ""

# Step 1: Authenticate (if needed)
echo "Step 1: Checking authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "Please authenticate with: gcloud auth login"
    exit 1
fi

# Step 2: Configure Docker for Artifact Registry
echo ""
echo "Step 2: Configuring Docker for Artifact Registry..."
gcloud auth configure-docker ${REGISTRY} --quiet

# Step 3: Build Docker image
echo ""
echo "Step 3: Building Docker image..."
cd src
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
cd ..

# Step 4: Tag image
echo ""
echo "Step 4: Tagging image for Artifact Registry..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME}

# Step 5: Push image
echo ""
echo "Step 5: Pushing image to Artifact Registry..."
echo "Image: ${FULL_IMAGE_NAME}"
docker push ${FULL_IMAGE_NAME}

# Step 6: Connect to GKE cluster
echo ""
echo "Step 6: Connecting to GKE cluster..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}

# Step 7: Create managed certificate
echo ""
echo "Step 7: Creating managed certificate..."
kubectl apply -f managed-certificate.yaml
echo "Waiting for certificate to be created..."
sleep 5

# Step 8: Deploy with Helm
echo ""
echo "Step 8: Deploying with Helm..."
cd helm-chart
helm upgrade --install lms-app ./lms-app --wait --timeout 5m
cd ..

# Step 9: Wait for pods to be ready
echo ""
echo "Step 9: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=lms-app --timeout=5m

# Step 10: Get status
echo ""
echo "=========================================="
echo "Deployment Status"
echo "=========================================="
echo ""
echo "Pods:"
kubectl get pods -l app.kubernetes.io/name=lms-app
echo ""
echo "Services:"
kubectl get svc -l app.kubernetes.io/name=lms-app
echo ""
echo "Ingress:"
kubectl get ingress -l app.kubernetes.io/name=lms-app
echo ""
echo "Managed Certificate:"
kubectl get managedcertificate variphi-lms-cert
echo ""

# Step 11: Get External IP
echo "=========================================="
echo "External IP for Domain Configuration"
echo "=========================================="
EXTERNAL_IP=$(kubectl get ingress -l app.kubernetes.io/name=lms-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")

if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "Pending..." ]; then
    echo "External IP is still being provisioned..."
    echo "Run this command to check later:"
    echo "  kubectl get ingress -l app.kubernetes.io/name=lms-app"
else
    echo ""
    echo "✅ External IP: $EXTERNAL_IP"
    echo ""
    echo "Configure your DNS (vgiskill.ai) with an A record pointing to: $EXTERNAL_IP"
    echo ""
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "To check pod logs:"
echo "  kubectl logs -l app.kubernetes.io/name=lms-app"
echo ""
echo "To check pod status:"
echo "  kubectl get pods -l app.kubernetes.io/name=lms-app"
echo ""

