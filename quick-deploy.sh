#!/bin/bash
# Quick deployment - tries to deploy everything
# If auth fails, run: gcloud auth login

set -e

echo "Attempting to push image and deploy..."
echo "If authentication fails, please run: gcloud auth login"
echo ""

# Try to push image (may need auth)
docker push asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest 2>&1 || {
    echo "⚠️  Image push failed. Please run: gcloud auth login"
    echo "Then run: docker push asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest"
}

# Try to apply certificate
kubectl apply -f managed-certificate.yaml 2>&1 || {
    echo "⚠️  Certificate apply failed. Please run: gcloud container clusters get-credentials gke-prod-asia-south1 --region asia-south1"
}

# Try to deploy with Helm
cd helm-chart
helm upgrade --install lms-app ./lms-app --wait 2>&1 || {
    echo "⚠️  Helm deploy failed. Please check cluster connection."
}

cd ..

echo ""
echo "Checking deployment status..."
kubectl get pods -l app.kubernetes.io/name=lms-app 2>&1 || true
kubectl get ingress -l app.kubernetes.io/name=lms-app 2>&1 || true

