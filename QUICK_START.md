# Quick Start - Deploy VariPhi LMS

All files are ready! Follow these steps:

## Step 1: Authenticate (One-time setup)

```bash
gcloud auth login
gcloud config set project variphi
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

## Step 2: Run Complete Deployment

```bash
./deploy-complete.sh
```

This script will:
1. ✅ Build Docker image
2. ✅ Push to Artifact Registry: `asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest`
3. ✅ Create managed certificate for SSL
4. ✅ Deploy with Helm
5. ✅ Show pod status and External IP

## Step 3: Get External IP

After deployment, get the IP:

```bash
kubectl get ingress -l app.kubernetes.io/name=lms-app
```

Configure DNS: Point `vgiskill.ai` A record to the IP shown.

## Step 4: Verify

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=lms-app

# Check logs
kubectl logs -l app.kubernetes.io/name=lms-app

# Check certificate status
kubectl get managedcertificate variphi-lms-cert
```

## Manual Steps (if script fails)

If the script encounters issues, run these manually:

```bash
# 1. Build and push image
cd src
docker build -t variphi/lms-app:latest .
docker tag variphi/lms-app:latest asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest
docker push asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest
cd ..

# 2. Connect to cluster
gcloud container clusters get-credentials gke-prod-asia-south1 --region asia-south1 --project variphi

# 3. Create certificate
kubectl apply -f managed-certificate.yaml

# 4. Deploy with Helm
cd helm-chart
helm upgrade --install lms-app ./lms-app
cd ..

# 5. Check status
kubectl get pods -l app.kubernetes.io/name=lms-app
kubectl get ingress -l app.kubernetes.io/name=lms-app
```

## Image Location

✅ **Artifact Registry Path**: `asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest`

This matches your repository structure:
- Repository: `vgiskill`
- Path: `lms-prod/variphi/lms-app`

