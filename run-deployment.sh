#!/bin/bash
# Complete deployment script - Run this after: gcloud auth login

set -e

PROJECT_ID="variphi"
CLUSTER_NAME="gke-prod-asia-south1"
REGION="asia-south1"
IMAGE_NAME="asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest"

echo "=========================================="
echo "🚀 VariPhi LMS - Complete Deployment"
echo "=========================================="
echo ""

# Step 1: Verify authentication
echo "✅ Step 1: Verifying authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Please run: gcloud auth login"
    exit 1
fi
echo "   Authenticated as: $(gcloud config get-value account)"
echo ""

# Step 2: Configure Docker
echo "✅ Step 2: Configuring Docker for Artifact Registry..."
gcloud auth configure-docker asia-south1-docker.pkg.dev --quiet
echo ""

# Step 3: Tag image (if not already tagged)
echo "✅ Step 3: Tagging Docker image..."
cd src
if ! docker images | grep -q "asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest"; then
    docker build -t variphi/lms-app:latest .
    docker tag variphi/lms-app:latest ${IMAGE_NAME}
fi
cd ..
echo ""

# Step 4: Push image
echo "✅ Step 4: Pushing image to Artifact Registry..."
echo "   Image: ${IMAGE_NAME}"
docker push ${IMAGE_NAME}
echo "   ✅ Image pushed successfully!"
echo ""

# Step 5: Connect to cluster
echo "✅ Step 5: Connecting to GKE cluster..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION} --project ${PROJECT_ID}
echo "   ✅ Connected to cluster: ${CLUSTER_NAME}"
echo ""

# Step 6: Create managed certificate
echo "✅ Step 6: Creating managed certificate..."
kubectl apply -f managed-certificate.yaml
echo "   ✅ Certificate created"
echo ""

# Step 7: Deploy with Helm
echo "✅ Step 7: Deploying with Helm..."
cd helm-chart
helm upgrade --install lms-app ./lms-app --wait --timeout 5m
cd ..
echo "   ✅ Helm deployment complete"
echo ""

# Step 8: Wait for pods
echo "✅ Step 8: Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=lms-app --timeout=5m || true
echo ""

# Step 9: Show status
echo "=========================================="
echo "📊 Deployment Status"
echo "=========================================="
echo ""
echo "📦 Pods:"
kubectl get pods -l app.kubernetes.io/name=lms-app -o wide
echo ""

echo "🔌 Services:"
kubectl get svc -l app.kubernetes.io/name=lms-app
echo ""

echo "🌐 Ingress:"
kubectl get ingress -l app.kubernetes.io/name=lms-app
echo ""

echo "🔒 Managed Certificate:"
kubectl get managedcertificate variphi-lms-cert
echo ""

# Step 10: Get External IP
echo "=========================================="
echo "🌍 External IP for DNS Configuration"
echo "=========================================="
EXTERNAL_IP=$(kubectl get ingress -l app.kubernetes.io/name=lms-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$EXTERNAL_IP" ]; then
    echo "⏳ External IP is still being provisioned..."
    echo ""
    echo "Run this command to check later:"
    echo "  kubectl get ingress -l app.kubernetes.io/name=lms-app"
    echo ""
    echo "Or run: ./check-status.sh"
else
    echo ""
    echo "✅ ✅ ✅ EXTERNAL IP: $EXTERNAL_IP ✅ ✅ ✅"
    echo ""
    echo "📝 Configure your DNS:"
    echo "   Domain: vgiskill.ai"
    echo "   Type: A"
    echo "   Value: $EXTERNAL_IP"
    echo "   TTL: 300 (or default)"
    echo ""
fi

echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📋 Useful commands:"
echo "   Check status: ./check-status.sh"
echo "   View logs: kubectl logs -l app.kubernetes.io/name=lms-app"
echo "   Get IP: kubectl get ingress -l app.kubernetes.io/name=lms-app"
echo ""

