# 🚀 Execute Frappe LMS Deployment

Since I cannot directly execute commands due to shell limitations, please run these steps manually or use the provided script.

## Quick Deploy (Recommended)

```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms
./deploy-frappe-lms.sh
```

## Manual Step-by-Step Deployment

### Step 1: Authenticate
```bash
gcloud auth login
gcloud config set project variphi
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

### Step 2: Build and Push Docker Image
```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms

# Build image (takes 15-20 minutes)
docker buildx build --platform linux/amd64 \
  -t asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest \
  --push .
```

**What this does:**
- Builds Frappe LMS with all dependencies
- Compiles frontend assets (yarn build)
- Sets up bench environment
- Creates production-ready image with pre-built assets

### Step 3: Connect to GKE Cluster
```bash
gcloud container clusters get-credentials gke-prod-asia-south1 \
  --region asia-south1 --project variphi
```

### Step 4: Deploy with Helm
```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms/helm-chart/lms-app

# Deploy
helm upgrade --install frappe-lms ./lms-app --wait --timeout 15m
```

### Step 5: Verify Deployment
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms --tail=50

# Check PVC
kubectl get pvc -l app.kubernetes.io/name=frappe-lms

# Check service
kubectl get svc -l app.kubernetes.io/name=frappe-lms

# Check ingress
kubectl get ingress -l app.kubernetes.io/name=frappe-lms
```

### Step 6: Get External IP
```bash
kubectl get ingress -l app.kubernetes.io/name=frappe-lms \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

## Expected Timeline

1. **Docker Build**: 15-20 minutes
2. **Helm Deploy**: 2-3 minutes
3. **Pod Startup**: 2-3 minutes (first time)
4. **Total**: ~20-25 minutes

## What Gets Deployed

- ✅ **Pod**: Single Frappe LMS pod
- ✅ **PVC**: 50GB persistent volume for sites
- ✅ **Service**: ClusterIP on port 80
- ✅ **Ingress**: GKE ingress for vgiskill.ai
- ✅ **Secrets**: DB password and admin password

## Troubleshooting

### Build Fails
- Check Docker is running: `docker ps`
- Check disk space: `df -h`
- Check network connectivity

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms
```

### Database Connection Issues
```bash
# Test from pod
kubectl exec -it <pod-name> -- nc -zv 10.30.0.2 3306
```

### PVC Not Binding
```bash
# Check storage class
kubectl get storageclass

# Check PVC events
kubectl describe pvc -l app.kubernetes.io/name=frappe-lms
```

## After Deployment

1. Wait for pod to be Ready (1/1)
2. Check ingress for external IP
3. Configure DNS if needed
4. Access: https://vgiskill.ai
5. Login: Administrator / admin@vgiskill2026

## Monitoring Commands

```bash
# Watch pod status
watch kubectl get pods -l app.kubernetes.io/name=frappe-lms

# Follow logs
kubectl logs -l app.kubernetes.io/name=frappe-lms -f

# Check resource usage
kubectl top pod -l app.kubernetes.io/name=frappe-lms
```

---

**Ready to deploy? Run:** `./deploy-frappe-lms.sh`

