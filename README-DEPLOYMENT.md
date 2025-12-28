# Frappe LMS (vgiskill_lms) - GKE Deployment Guide

This guide explains how to deploy Frappe LMS on GKE using Helm with a pre-built Docker image containing all assets.

## Architecture

```
│      GKE Pod (Single Frappe LMS)       │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │  Prebuilt Docker Image           │  │
│  │----------------------------------│  │
│  │ - Python + Node + Yarn           │  │
│  │ - Frappe Framework               │  │
│  │ - LMS app                        │  │
│  │ - bench build (assets ready)     │  │
│  │ - gunicorn + nginx               │  │
│  │                                  │  │
│  │ Assets baked inside image ✅     │  │
│  │ No runtime compilation           │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Mounted Persistent Volume (PVC)       │
│  ┌──────────────────────────────────┐  │
│  │ /home/frappe/frappe-bench/sites │  │
│  │  ├── site_config.json            │  │
│  │  ├── vgiskill.ai/                │  │
│  │  │   ├── public/files            │  │
│  │  │   ├── private/files           │  │
│  │  │   └── site_config.json        │  │
│  └──────────────────────────────────┘  
```

## Features

- ✅ **Pre-built Assets**: All frontend assets are compiled during Docker build
- ✅ **Fast Pod Startup**: No compilation needed when pod starts
- ✅ **Persistent Storage**: Sites data stored in PVC (50GB)
- ✅ **External MariaDB**: Connects to external DB at 10.30.0.2:3306
- ✅ **Single Pod**: Runs in one pod as requested
- ✅ **Production Ready**: Gunicorn + Nginx + Supervisor

## Prerequisites

1. Docker installed
2. kubectl configured for GKE cluster
3. Helm 3.x installed
4. Access to GKE cluster: `gke-prod-asia-south1`
5. Access to Artifact Registry: `vgiskill/lms-prod`

## Quick Deploy

```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms
./build-and-deploy.sh
```

## Manual Deployment Steps

### 1. Build Docker Image

```bash
cd /Users/shivam/Downloads/variphi-lms-app/vgiskill_lms

# Build and push image
docker buildx build --platform linux/amd64 \
  -t asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest \
  --push .
```

**Note**: This build takes 15-20 minutes as it:
- Installs all Python dependencies
- Builds frontend assets (yarn build)
- Compiles Frappe framework
- Sets up bench environment

### 2. Deploy with Helm

```bash
# Connect to cluster
gcloud container clusters get-credentials gke-prod-asia-south1 \
  --region asia-south1 --project variphi

# Deploy
cd helm-chart/lms-app
helm upgrade --install frappe-lms ./lms-app
```

### 3. Verify Deployment

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms --tail=50

# Check PVC
kubectl get pvc -l app.kubernetes.io/name=frappe-lms

# Check ingress
kubectl get ingress -l app.kubernetes.io/name=frappe-lms
```

## Configuration

### Database Connection

The application connects to external MariaDB:
- **Host**: 10.30.0.2
- **Port**: 3306
- **Database**: lms_db
- **User**: vgi_skill
- **Password**: vgiskill@2026

Configured in `helm-chart/lms-app/values.yaml`:

```yaml
db:
  host: "10.30.0.2"
  port: 3306
  user: "vgi_skill"
  password: "vgiskill@2026"
  name: "lms_db"
```

### Persistent Storage

- **Storage Class**: standard-rwo
- **Size**: 50Gi
- **Mount Path**: /home/frappe/frappe-bench/sites
- **Access Mode**: ReadWriteOnce

### Resources

- **CPU**: 1000m request, 2000m limit
- **Memory**: 2Gi request, 4Gi limit

### Site Configuration

- **Site Name**: vgiskill.ai
- **Admin Password**: admin@vgiskill2026

## Image Location

**Artifact Registry**: `asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/frappe-lms:latest`

- Repository: `vgiskill`
- Path: `lms-prod/frappe-lms`

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -l app.kubernetes.io/name=frappe-lms

# Check logs
kubectl logs -l app.kubernetes.io/name=frappe-lms
```

### Database Connection Issues

```bash
# Test connectivity from pod
kubectl exec -it <pod-name> -- nc -zv 10.30.0.2 3306
```

### Assets Not Loading

The image includes pre-built assets. If issues occur:
1. Check if assets directory exists in image
2. Verify nginx configuration
3. Check pod logs for asset serving errors

### PVC Issues

```bash
# Check PVC status
kubectl get pvc -l app.kubernetes.io/name=frappe-lms

# Check PV
kubectl get pv
```

## Application Access

Once deployed and ingress is configured:
- **URL**: https://vgiskill.ai
- **Admin Login**: Administrator / admin@vgiskill2026

## File Structure

```
vgiskill_lms/
├── Dockerfile              # Multi-stage build with pre-built assets
├── docker/
│   ├── entrypoint.sh      # Startup script
│   ├── supervisord.conf   # Process manager config
│   └── nginx.conf         # Nginx configuration
├── helm-chart/
│   └── lms-app/
│       ├── Chart.yaml
│       ├── values.yaml    # Configuration
│       └── templates/
│           ├── deployment.yaml
│           ├── pvc.yaml   # Persistent volume claim
│           ├── service.yaml
│           └── ...
└── build-and-deploy.sh    # Automated deployment script
```

## Key Benefits

1. **Fast Startup**: Assets pre-built, no compilation on pod start
2. **Reliability**: If pod crashes, new pod starts quickly
3. **Persistent Data**: Sites data survives pod restarts
4. **Production Ready**: Gunicorn + Nginx for performance
5. **Single Pod**: Simple deployment as requested

## Next Steps

After deployment:
1. Wait for pod to be ready (2-3 minutes)
2. Check ingress for external IP
3. Configure DNS if needed
4. Access application at https://vgiskill.ai

