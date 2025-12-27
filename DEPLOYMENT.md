# Quick Deployment Guide

## Step 1: Build and Push Docker Image

```bash
# Set your GCP project ID
export GCP_PROJECT_ID=your-project-id

# Option 1: Using GCR (Google Container Registry)
cd src
docker build -t variphi/lms-app:latest .
docker tag variphi/lms-app:latest gcr.io/${GCP_PROJECT_ID}/variphi/lms-app:latest
docker push gcr.io/${GCP_PROJECT_ID}/variphi/lms-app:latest

# Option 2: Using Artifact Registry
docker tag variphi/lms-app:latest asia-south1-docker.pkg.dev/${GCP_PROJECT_ID}/your-repo/variphi/lms-app:latest
docker push asia-south1-docker.pkg.dev/${GCP_PROJECT_ID}/your-repo/variphi/lms-app:latest
```

## Step 2: Update Helm Values

Edit `helm-chart/lms-app/values.yaml` and update the image repository:

```yaml
image:
  repository: gcr.io/YOUR_PROJECT_ID/variphi/lms-app  # or Artifact Registry path
  tag: "latest"
```

## Step 3: Create Managed Certificate (if not exists)

```bash
kubectl apply -f managed-certificate.yaml
```

Wait for the certificate to be ACTIVE:
```bash
kubectl describe managedcertificate variphi-lms-cert
```

## Step 4: Deploy with Helm

```bash
# Connect to your GKE cluster
gcloud container clusters get-credentials gke-prod-asia-south1 --region asia-south1

# Deploy
cd helm-chart
helm install lms-app ./lms-app

# Or upgrade if already installed
helm upgrade lms-app ./lms-app
```

## Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=lms-app

# Check service
kubectl get svc -l app.kubernetes.io/name=lms-app

# Check ingress
kubectl get ingress -l app.kubernetes.io/name=lms-app

# Check logs
kubectl logs -l app.kubernetes.io/name=lms-app
```

## Step 6: Configure DNS

Point your domain `vgiskill.ai` to the GCLB IP address shown in the Ingress:

```bash
# Get the IP address
kubectl get ingress -l app.kubernetes.io/name=lms-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

Add an A record in your DNS provider:
- Type: A
- Name: @ (or vgiskill.ai)
- Value: <GCLB_IP>

## Step 7: Test

Once DNS propagates and SSL certificate is active:
- Visit: https://vgiskill.ai
- You should see: "Welcome to VariPhi" and "External DB connected successfully"

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### DB connection issues
```bash
# Test connectivity from a pod
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- mysql -h 10.30.0.2 -u vgi_skill -p
```

### Ingress not working
```bash
kubectl describe ingress <ingress-name>
kubectl get managedcertificate variphi-lms-cert
```

