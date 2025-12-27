# 🚀 START HERE - Deploy VariPhi LMS

## Quick Start (2 Steps)

### Step 1: Authenticate (One-time, if needed)
```bash
gcloud auth login
```

### Step 2: Run Deployment
```bash
./run-deployment.sh
```

That's it! The script will:
- ✅ Build and push Docker image to Artifact Registry (`vgiskill/lms-prod`)
- ✅ Create managed certificate for SSL
- ✅ Deploy application with Helm
- ✅ Show pod status
- ✅ Display External IP for DNS configuration

---

## What You'll Get

After running the script, you'll see:
- **External IP** - Use this to configure DNS for `vgiskill.ai`
- **Pod Status** - All pods running
- **Certificate Status** - SSL certificate being provisioned

## After Deployment

1. **Configure DNS**: Point `vgiskill.ai` A record to the External IP shown
2. **Wait**: 5-15 minutes for DNS propagation and SSL certificate activation
3. **Test**: Open `https://vgiskill.ai` in your browser
4. **Verify**: You should see "Welcome to VariPhi" and "External DB connected successfully"

## Check Status Anytime

```bash
./check-status.sh
```

## Image Location

✅ **Artifact Registry**: `asia-south1-docker.pkg.dev/variphi/vgiskill/lms-prod/variphi/lms-app:latest`

- Repository: `vgiskill` ✅
- Path: `lms-prod/variphi/lms-app` ✅

---

**Ready? Run:** `./run-deployment.sh`

