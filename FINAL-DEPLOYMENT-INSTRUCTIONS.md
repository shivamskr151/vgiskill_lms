# 🚀 FINAL DEPLOYMENT INSTRUCTIONS

## ✅ All Files Are Ready!

I've prepared everything for Frappe LMS deployment. Due to shell access limitations, please execute the deployment using the provided script.

## 🎯 Execute Deployment (Choose One Method)

### Method 1: Automated Script (Recommended)

```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms
chmod +x RUN-ME.sh
./RUN-ME.sh
```

This single command will:
- ✅ Build Docker image (15-20 min)
- ✅ Push to Artifact Registry
- ✅ Deploy to GKE with Helm
- ✅ Show status and external IP

### Method 2: Step-by-Step Manual

#### Step 1: Authenticate
```bash
gcloud auth login
gcloud config set project variphi
gcloud auth configure-docker asia-south1-docker.pkg.dev
```

#### Step 2: Build & Push Image
```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms

docker buildx build --platform linux/amd64 \
  -t asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest \
  --push .
```

**Time**: 15-20 minutes

#### Step 3: Deploy to GKE
```bash
# Connect to cluster
gcloud container clusters get-credentials gke-prod-asia-south1 \
  --region asia-south1 --project variphi

# Deploy with Helm
cd helm-chart/lms-app
helm upgrade --install frappe-lms ./lms-app --wait --timeout 15m
```

#### Step 4: Verify
```bash
# Check pod
kubectl get pods -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms --tail=50

# Check ingress IP
kubectl get ingress -l app.kubernetes.io/name=frappe-lms
```

## 📋 What Gets Deployed

- **Pod**: Single Frappe LMS pod with pre-built assets
- **PVC**: 50GB persistent volume for sites data
- **Service**: ClusterIP on port 80
- **Ingress**: GKE ingress for vgiskill.ai
- **Database**: External MariaDB at 10.30.0.2:3306

## ⏱️ Expected Timeline

- Docker Build: 15-20 minutes
- Helm Deploy: 2-3 minutes
- Pod Startup: 2-3 minutes
- **Total**: ~20-25 minutes

## 🔍 Verification Checklist

After deployment, verify:

```bash
# 1. Pod is Running
kubectl get pods -l app.kubernetes.io/name=frappe-lms
# Should show: STATUS = Running, READY = 1/1

# 2. PVC is Bound
kubectl get pvc -l app.kubernetes.io/name=frappe-lms
# Should show: STATUS = Bound

# 3. Service Created
kubectl get svc -l app.kubernetes.io/name=frappe-lms
# Should show: TYPE = ClusterIP, PORT = 80

# 4. Ingress Has IP
kubectl get ingress -l app.kubernetes.io/name=frappe-lms
# Should show: ADDRESS = <IP address>

# 5. Logs Show No Errors
kubectl logs -l app.kubernetes.io/name=frappe-lms --tail=50
# Should show: Server running, no errors
```

## 🎯 Configuration Summary

- **Image**: `asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest`
- **Database**: `10.30.0.2:3306` (lms_db)
- **Site Name**: `vgiskill.ai`
- **Admin Password**: `admin@vgiskill2026`
- **Storage**: 50GB PVC
- **Resources**: 1-2 CPU, 2-4Gi memory

## 🚨 Troubleshooting

### Build Fails
```bash
# Check Docker
docker ps

# Check disk space
df -h

# Retry build
docker buildx build --platform linux/amd64 \
  -t asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest \
  --push . --no-cache
```

### Pod Not Starting
```bash
# Check events
kubectl describe pod -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms

# Check PVC
kubectl get pvc -l app.kubernetes.io/name=frappe-lms
kubectl describe pvc -l app.kubernetes.io/name=frappe-lms
```

### Database Connection Issues
```bash
# Test from pod
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=frappe-lms -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -- nc -zv 10.30.0.2 3306
```

## 🎉 After Deployment

1. Wait for pod to be Ready (1/1)
2. Get external IP from ingress
3. Configure DNS: Point vgiskill.ai to the IP
4. Access: https://vgiskill.ai
5. Login: Administrator / admin@vgiskill2026

## 📞 Quick Commands Reference

```bash
# Watch pod status
watch kubectl get pods -l app.kubernetes.io/name=frappe-lms

# Follow logs
kubectl logs -l app.kubernetes.io/name=frappe-lms -f

# Get all resources
kubectl get all -l app.kubernetes.io/name=frappe-lms

# Delete and redeploy
helm uninstall frappe-lms
helm install frappe-lms ./helm-chart/lms-app
```

---

## ✅ READY TO DEPLOY!

Run: `./RUN-ME.sh` or follow manual steps above.

All files are prepared and ready! 🚀

