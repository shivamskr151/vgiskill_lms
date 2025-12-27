#!/bin/bash

# VariPhi LMS Deployment Script
# This script builds the Docker image and deploys using Helm

set -e

PROJECT_ID="${GCP_PROJECT_ID:-variphi}"
IMAGE_NAME="variphi/lms-app"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="asia-south1-docker.pkg.dev"
REPOSITORY="vgiskill"
IMAGE_PATH="lms-prod"

FULL_IMAGE_NAME="${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_PATH}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building Docker image..."
cd src
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo "Tagging image for Artifact Registry..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE_NAME}

echo "Pushing image to Artifact Registry..."
docker push ${FULL_IMAGE_NAME}

echo "Image pushed successfully: ${FULL_IMAGE_NAME}"

echo "Deploying with Helm..."
cd ..
helm upgrade --install lms-app ./lms-app

echo "Deployment complete!"
echo "Check status with: kubectl get pods -l app.kubernetes.io/name=lms-app"

