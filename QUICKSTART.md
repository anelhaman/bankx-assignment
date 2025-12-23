# Quick Start Guide - BankX Azure Infrastructure

Complete setup guide from zero to production in minutes.

## 1. Prerequisites Check

```bash
# Verify installed tools
terraform version          # >= 1.0
az version                 # Azure CLI
kubectl version           # Kubernetes CLI
docker --version          # Docker
git --version             # Git
gh --version              # GitHub CLI (for secrets setup)
```

## 2. Clone Repository

```bash
git clone https://github.com/your-username/bankx-assignment.git
cd bankx-assignment
```

## 3. Azure Setup (One-Time)

### 3a. Create Service Principal for GitHub Actions

```bash
# Set your values
export GITHUB_REPO_OWNER="rachen"
export GITHUB_REPO_NAME="bankx-assignment"
export AZURE_LOCATION="East Asia"

# Run setup script (coming next)
bash azure-setup.sh
```

### 3b. Create Terraform State Storage

```bash
# Run terraform state setup
bash terraform-state-setup.sh
```

## 4. Add GitHub Secrets

```bash
# Login to GitHub CLI
gh auth login

# Run secrets setup script
bash github-secrets-setup.sh
```

Or add manually via GitHub UI:
- Settings → Secrets and variables → Actions
- Add all secrets from [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

## 5. Deploy Infrastructure


## 5. Deploy Infrastructure (Quick Setup)

```bash
# 1. Create a feature branch
git checkout -b feature/infrastructure

# 2. Make changes (optional)
# Edit terraform.tfvars or variables

# 3. Commit and push
git add .
git commit -m "feat: initial infrastructure deployment"
git push origin feature/infrastructure

# 4. Create Pull Request on GitHub
# 5. Merge to main
# 6. Watch workflow run (GitHub Actions tab)

# Infrastructure will be automatically deployed to Azure!
```

## 6. Deploy Application

### First Deployment (Create Image)

```bash
# 1. Create a feature branch
git checkout -b feature/app-initial

# 2. Commit app code (already in repo)
git add package.json app/ Dockerfile
git commit -m "feat: initial nodejs app"
git push origin feature/app-initial

# 3. Create PR → Merge to main
# Workflow will:
# - Build Docker image
# - Push to ACR
# - Deploy to AKS
```

### Update Application

```bash
# 1. Make code changes
# Edit app/app.js or other files

# 2. Commit and push
git add app/app.js
git commit -m "feat: update app logic"
git push origin feature/app-update

# 3. Merge to main
# Workflow will automatically:
# - Build new image
# - Push to ACR
# - Update AKS deployment
# - Perform health checks
```

## 7. Verify Deployment

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group bankx-prod-rg \
  --name bankx-aks-prod

# Check nodes
kubectl get nodes

# Check deployment
kubectl get deployment -n nodejs-hello-ns

# Check pods
kubectl get pods -n nodejs-hello-ns

# Get service IP
kubectl get svc nodejs-hello -n nodejs-hello-ns

# Check logs
kubectl logs -f -n nodejs-hello-ns deployment/nodejs-hello

# Test application
curl http://<service-ip>/
# Returns: Hello World
```

## 8. Verify Monitoring

```bash
# View Application Insights
az monitor app-insights show \
  --name nodejs-hello-appinsights \
  --resource-group bankx-prod-rg

# View logs in Log Analytics
az monitor log-analytics query \
  --workspace bankx-logs-prod \
  --analytics-query "ContainerLog | head 100"

# Check request count
az monitor metrics list \
  --resource nodejs-hello-appinsights \
  --metric RequestCount
```

## 9. Access Application

### Get Public IP

```bash
# From Terraform outputs
terraform output application_gateway_public_ip

# Or from Azure CLI
az network public-ip show \
  --name appgw-pip \
  --resource-group bankx-prod-rg \
  --query ipAddress -o tsv
```

### Test Application

```bash
# Get IP
IP=$(terraform output -raw application_gateway_public_ip)

# Test endpoint
curl http://$IP/
# Expected: Hello World

# Check health
curl http://$IP/health
# Expected: {"status":"healthy",...}

# View metrics
curl http://$IP/metrics
# Expected: {"requestCount":...}
```

## 10. Monitor Application

### Via Azure Portal

1. Navigate to Application Insights
2. View requests, performance, failures
3. Check custom metrics (request count)
4. Set up alerts

### Via kubectl

```bash
# Watch deployments
kubectl get deployment -n nodejs-hello-ns -w

# Watch pods
kubectl get pods -n nodejs-hello-ns -w

# Stream logs
kubectl logs -f -n nodejs-hello-ns deployment/nodejs-hello

# Check resource usage
kubectl top pods -n nodejs-hello-ns
kubectl top nodes
```

### Via Azure CLI

```bash
# Get logs
az monitor log-analytics query \
  --workspace bankx-logs-prod \
  --analytics-query 'requests | where name == "GET /" | summarize count()'

# Get metrics
az monitor metrics list \
  --resource <app-insights-id> \
  --metric "RequestCount"
```

## 11. Scaling Application

### Auto-Scaling (Already Configured)

```bash
# View HPA status
kubectl get hpa -n nodejs-hello-ns

# Check HPA details
kubectl describe hpa nodejs-hello-hpa -n nodejs-hello-ns

# View metrics driving scaling
kubectl get hpa nodejs-hello-hpa -n nodejs-hello-ns -w
```

### Manual Scaling

```bash
# Scale replicas
kubectl scale deployment nodejs-hello \
  -n nodejs-hello-ns \
  --replicas=5

# Scale AKS nodes
az aks nodepool scale \
  --resource-group bankx-prod-rg \
  --cluster-name bankx-aks-prod \
  --name default \
  --node-count 4
```

## 12. Troubleshooting

### Check Workflow Logs

```bash
# List recent workflows
gh workflow list -R $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME

# View workflow run
gh run list -R $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME

# View logs for a run
gh run view <run-id> -R $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME
```

### Common Issues

```bash
# Issue: Pod not starting
kubectl describe pod <pod-name> -n nodejs-hello-ns

# Issue: Image pull errors
kubectl logs <pod-name> -n nodejs-hello-ns

# Issue: Network issues
kubectl get networkpolicy -n nodejs-hello-ns

# Issue: Resource constraints
kubectl top nodes
kubectl describe node <node-name>

# Issue: Service not accessible
kubectl get svc -n nodejs-hello-ns
kubectl get endpoints -n nodejs-hello-ns
```

## 13. Cleanup

### Destroy Infrastructure

```bash
# Via Terraform
terraform destroy -var-file="terraform.tfvars" -auto-approve

# Via GitHub Actions (push to main)
# Create a pull request that runs destroy
# Not recommended - keep for safety
```

### Remove GitHub Secrets

```bash
gh secret list -R $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME

# Delete specific secret
gh secret delete SECRET_NAME -R $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME
```

### Clean up Azure Resources

```bash
# Delete resource group (removes all resources)
az group delete \
  --name bankx-prod-rg \
  --yes \
  --no-wait

# Delete storage account (for Terraform state)
az storage account delete \
  --name <storage-account-name> \
  --resource-group bankx-prod-rg \
  --yes
```

## 14. Documentation Links

- [Full Setup Guide](GITHUB_ACTIONS_SETUP.md)
- [Infrastructure README](README.md)
- [Terraform Modules](modules/)
- [Kubernetes Resources](kubernetes.tf)

## Support

For issues or questions:
1. Check [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) troubleshooting section
2. Check workflow logs in GitHub Actions
3. Check AKS cluster logs: `kubectl get events -n nodejs-hello-ns`
4. Check Azure resources in portal

---

**Version:** 1.0  
**Last Updated:** December 23, 2025
