# BankX AKS Deployment - Complete Guide

## 🚀 Deploy from Scratch (Start Here)

### Step 1: Set Environment Variables
```bash
# Run these commands (from azure-secrets.txt):
set -x ARM_CLIENT_ID (grep AZURE_CLIENT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_TENANT_ID (grep AZURE_TENANT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_SUBSCRIPTION_ID (grep AZURE_SUBSCRIPTION_ID azure-secrets.txt | cut -d= -f2)

# Verify they're set:
echo $ARM_CLIENT_ID
```

### Step 2: Deploy Infrastructure
```bash
# This creates AKS cluster, ACR, VNet, monitoring (10-15 minutes)
terraform apply -var-file="terraform.tfvars"

# Type 'yes' when prompted
```

**Wait for terraform to complete.** When done, you'll see "Apply complete!"

### Step 3: Get ACR Credentials (After Terraform Completes)
```bash
# Get ACR name and credentials:
az acr list --resource-group bankx-prod-rg --query "[].{name:name,loginServer:loginServer}" -o table
az acr credential show --resource-group bankx-prod-rg --name <ACR_NAME>

# Save these for GitHub Secrets (next step)
```

### Step 4: Add GitHub Secrets
Go to: GitHub repo → Settings → Secrets and variables → Actions

Add these 5 secrets:
```
ACR_LOGIN_SERVER    = <ACR>.azurecr.io (from step 3)
ACR_USERNAME        = <from step 3>
ACR_PASSWORD        = <from step 3>
AKS_RESOURCE_GROUP  = bankx-prod-rg
AZURE_CREDENTIALS   = (see below)
```

For AZURE_CREDENTIALS, create JSON:
```json
{
  "clientId": "<ARM_CLIENT_ID from azure-secrets.txt>",
  "clientSecret": "<not needed for OIDC>",
  "subscriptionId": "<ARM_SUBSCRIPTION_ID from azure-secrets.txt>",
  "tenantId": "<ARM_TENANT_ID from azure-secrets.txt>"
}
```

### Step 4.5: Set Registry / Image as GitHub Variables

Add repository-level variables so workflows can read the registry and image name without hardcoding them in the YAML.

- UI: GitHub → Settings → Variables and secrets → Actions → New repository variable
  - Name: `REGISTRY`  Value: `<your-acr>.azurecr.io`
  - Name: `IMAGE_NAME` Value: `nodejs-hello` (or your image name)

- CLI (optional):
```bash
# Set repository variables with GitHub CLI (if available)
gh variable set REGISTRY --value "<your-acr>.azurecr.io"
gh variable set IMAGE_NAME --value "nodejs-hello"
```

Your workflows read these via `env` (see `.github/workflows/deploy-nodejs-app.yml`):
```
env:
  REGISTRY: ${{ secrets.ACR_LOGIN_SERVER }}   # or ${{ vars.REGISTRY }} if using repository variables
  IMAGE_NAME: ${{ vars.IMAGE_NAME }}
```

Note: Use `secrets` for sensitive values (ACR credentials) and `variables` (`vars`) for non-sensitive config like `IMAGE_NAME`.

### Step 5: Deploy Application
```bash
# Option A: Automatic (recommended)
git add .
git commit -m "Deploy to AKS"
git push origin main

# GitHub Actions will automatically:
# - Build Docker image
# - Push to ACR with version tag
# - Deploy to AKS
# - Verify deployment

# Watch progress: GitHub → Actions tab
```

```bash
# Option B: Manual deployment
./deploy.sh latest production
```

### Step 6: Access Your App
```bash
# Get AKS credentials
az aks get-credentials --resource-group bankx-prod-rg --name bankx-aks-prod

# Check pods are running
kubectl get pods -n bankx-app

# Get external IP
kubectl get svc nodejs-hello -n bankx-app

# Visit: http://<EXTERNAL-IP>
```

✅ **Done!** Your app is live!

---

## Required GitHub Secrets for Azure Login

To enable the pipeline to authenticate with Azure, you must add these secrets to your GitHub repository:

Go to: GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:
```
AZURE_CLIENT_ID      = <your Azure service principal client ID>
AZURE_TENANT_ID      = <your Azure tenant ID>
AZURE_SUBSCRIPTION_ID = <your Azure subscription ID>
```

- These are required for the Azure login step in the pipeline:
  - `client-id: ${{ secrets.AZURE_CLIENT_ID }}`
  - `tenant-id: ${{ secrets.AZURE_TENANT_ID }}`
  - `subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}`

If any are missing or blank, the pipeline will fail to authenticate with Azure.

---

## How to Get Azure Service Principal Credentials

To obtain the required Azure credentials for GitHub Actions, follow these steps:

### 1. Create a Service Principal (SP) in Azure

Open your terminal and run:
```bash
az ad sp create-for-rbac --name "bankx-github-actions" --role contributor --scopes /subscriptions/<your-subscription-id>
```
This will output JSON like:
```
{
  "appId": "<AZURE_CLIENT_ID>",
  "displayName": "bankx-github-actions",
  "password": "<AZURE_CLIENT_SECRET>",
  "tenant": "<AZURE_TENANT_ID>"
}
```

### 2. Find Your Subscription ID
```bash
az account show --query id -o tsv
```

### 3. Add These Values to GitHub Secrets
- AZURE_CLIENT_ID: `appId` from above
- AZURE_TENANT_ID: `tenant` from above
- AZURE_SUBSCRIPTION_ID: from step 2

Go to: GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Paste each value in the corresponding secret.

---

## Troubleshooting

### Issue: "terraform apply" fails or hangs

**Solution:**
```bash
# 1. Verify environment variables are set
echo $ARM_CLIENT_ID
echo $ARM_TENANT_ID  
echo $ARM_SUBSCRIPTION_ID

# 2. If empty, set them again:
set -x ARM_CLIENT_ID (grep AZURE_CLIENT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_TENANT_ID (grep AZURE_TENANT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_SUBSCRIPTION_ID (grep AZURE_SUBSCRIPTION_ID azure-secrets.txt | cut -d= -f2)

# 3. Verify Azure login
az account show

# 4. Run terraform init again
terraform init

# 5. Try terraform plan first
terraform plan -var-file="terraform.tfvars"
```

### Issue: Pods show "ImagePullBackOff"

**Solution:**
```bash
# ACR credentials issue - recreate secret:
kubectl create secret docker-registry acr-secret \
  --docker-server=<ACR_LOGIN_SERVER> \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=bankx-app --dry-run=client -o yaml | kubectl apply -f -

# Restart pods:
kubectl rollout restart deployment/nodejs-hello -n bankx-app
```

### Issue: Service has no EXTERNAL-IP

**Solution:**
```bash
# Wait 2-3 minutes for Azure to assign IP
kubectl get svc nodejs-hello -n bankx-app -w

# Check events
kubectl describe svc nodejs-hello -n bankx-app
```

---

## Architecture Overview

**Infrastructure (Terraform):**
- AKS Cluster (Kubernetes)
- Azure Container Registry (ACR)
- Virtual Network + Subnets
- Log Analytics + Application Insights
- Application Gateway

**Application Deployment (Kubernetes YAML + GitHub Actions):**
- Build Docker image
- Tag with version: `v{BUILD_NUMBER}-{COMMIT_SHA}`
- Push to ACR
- Deploy to AKS via kubectl

---

## Deployment Workflow

```
Code Change → git push origin main
    ↓
GitHub Actions (.github/workflows/deploy.yaml)
    ├─ Build Docker image
    ├─ Tag: v42-abc123f
    ├─ Push to ACR
    ├─ Update k8s/deployment.yaml
    ├─ Deploy: kubectl apply -f k8s/
    └─ Verify: kubectl rollout status
    ↓
App is LIVE (2-5 minutes)
```

---

## Files Structure

```
k8s/                        # Kubernetes manifests
├── deployment.yaml         # Main app deployment
├── service.yaml            # LoadBalancer service
├── namespace.yaml          # bankx-app namespace
├── configmap.yaml          # App configuration
└── ingress.yaml            # Application Gateway ingress

.github/workflows/
└── deploy.yaml             # CI/CD pipeline

deploy.sh                   # Manual deployment script

Terraform files:
├── main.tf                 # Core infrastructure
├── variables.tf
├── terraform.tfvars
└── modules/                # AKS, networking, monitoring
```

---

## Common Commands

### Check Deployment
```bash
# Get AKS credentials
az aks get-credentials --resource-group bankx-prod-rg --name bankx-aks-prod

# Check pods
kubectl get pods -n bankx-app

# View logs
kubectl logs -n bankx-app -l app=nodejs-hello -f

# Get service external IP
kubectl get svc nodejs-hello -n bankx-app
```

### Rollback
```bash
# Undo last deployment
kubectl rollout undo deployment/nodejs-hello -n bankx-app

# View history
kubectl rollout history deployment/nodejs-hello -n bankx-app
```

### Manual Deployment
```bash
# Deploy specific version
./deploy.sh v42-abc123f production

# Deploy latest
./deploy.sh latest production

# Direct kubectl
kubectl apply -f k8s/
```

---

## Troubleshooting

### Terraform apply fails
```bash
# Verify environment variables are set
echo $ARM_CLIENT_ID
echo $ARM_TENANT_ID
echo $ARM_SUBSCRIPTION_ID

# If not set, run:
set -x ARM_CLIENT_ID (grep AZURE_CLIENT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_TENANT_ID (grep AZURE_TENANT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_SUBSCRIPTION_ID (grep AZURE_SUBSCRIPTION_ID azure-secrets.txt | cut -d= -f2)

# Verify Azure login
az account show

# Re-run terraform init if needed
terraform init
```

### Pods not starting
```bash
# Describe pod to see error
kubectl describe pod <POD_NAME> -n bankx-app

# Check events
kubectl get events -n bankx-app --sort-by='.lastTimestamp'

# Common issue: ImagePullBackOff (ACR authentication)
# Solution: Recreate ACR secret
kubectl create secret docker-registry acr-secret \
  --docker-server=<ACR_LOGIN_SERVER> \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=bankx-app --dry-run=client -o yaml | kubectl apply -f -
```

### Service has no external IP
```bash
# Check service status
kubectl describe svc nodejs-hello -n bankx-app

# Check LoadBalancer quota in Azure portal
# Or wait 2-3 minutes for IP assignment
```

---

## Image Versioning

Each build creates unique version:
```
v42-abc123f   ← Build #42, commit abc123f
v43-def456g   ← Build #43, commit def456g
latest        ← Always points to latest
```

---

## Next Steps After Setup

1. ✅ Infrastructure deployed (`terraform apply`)
2. ✅ GitHub Secrets added
3. ✅ First deployment (`git push origin main`)
4. 📊 Monitor: GitHub Actions tab + `kubectl get pods -n bankx-app`
5. 🌐 Access: Get external IP with `kubectl get svc nodejs-hello -n bankx-app`

---

## Key Features

✅ **Automatic deployments** - Every push to main deploys automatically  
✅ **Image versioning** - Each build gets unique tag  
✅ **Easy rollbacks** - One command rollback  
✅ **Zero downtime** - Rolling update strategy  
✅ **Production monitoring** - Log Analytics + Application Insights  
✅ **Auto-scaling** - 2-10 pods based on CPU/Memory  

---

## Support

- **GitHub Actions logs**: GitHub → Actions tab
- **Pod logs**: `kubectl logs -n bankx-app -l app=nodejs-hello`
- **Azure Portal**: Check AKS cluster, ACR, Log Analytics

**Ready to deploy?** Run `terraform apply -var-file="terraform.tfvars"`
