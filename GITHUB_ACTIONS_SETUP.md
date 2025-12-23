# GitHub Actions Pipelines Setup Guide

This guide provides step-by-step instructions to set up the GitHub Actions CI/CD pipelines for the BankX Azure infrastructure and Node.js application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Setup](#azure-setup)
3. [GitHub Secrets Configuration](#github-secrets-configuration)
4. [Pipeline Overview](#pipeline-overview)
5. [Testing the Pipelines](#testing-the-pipelines)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- GitHub repository with GitHub Actions enabled
- Azure subscription with Owner or Contributor role
- Azure CLI installed locally
- kubectl installed locally
- Docker installed locally (for building images)

---

## Azure Setup

### 1. Create Service Principal for OIDC Authentication

OIDC (OpenID Connect) is recommended over service principal secrets for better security.

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RESOURCE_GROUP="bankx-prod-rg"
GITHUB_REPO_OWNER="your-github-username"
GITHUB_REPO_NAME="bankx-assignment"

# Create Azure AD App Registration
APP_REGISTRATION=$(az ad app create \
  --display-name "github-oidc-bankx" \
  --query appId \
  -o tsv)

echo "App Registration ID: $APP_REGISTRATION"

# Create Service Principal
SERVICE_PRINCIPAL=$(az ad sp create \
  --id $APP_REGISTRATION \
  --query id \
  -o tsv)

echo "Service Principal ID: $SERVICE_PRINCIPAL"

# Assign Contributor role to Service Principal
az role assignment create \
  --assignee $SERVICE_PRINCIPAL \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Create Federated Credentials (for OIDC)
GITHUB_ISSUER="https://token.actions.githubusercontent.com"

az ad app federated-credential create \
  --id $APP_REGISTRATION \
  --parameters \
    issuer=$GITHUB_ISSUER \
    subject="repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:ref:refs/heads/main" \
    audiences="api://AzureADTokenExchange" \
    description="GitHub Actions - Main Branch"

az ad app federated-credential create \
  --id $APP_REGISTRATION \
  --parameters \
    issuer=$GITHUB_ISSUER \
    subject="repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:environment:production" \
    audiences="api://AzureADTokenExchange" \
    description="GitHub Actions - Production Environment"
```

### 2. Create Terraform State Storage Account

```bash
STORAGE_ACCOUNT_NAME="bankxtfstate$(date +%s | sha256sum | cut -c1-10)"
RESOURCE_GROUP="bankx-prod-rg"
CONTAINER_NAME="tfstate"

# Create resource group if it doesn't exist
az group create \
  --name $RESOURCE_GROUP \
  --location "East Asia"

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "East Asia" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --access-tier "Hot" \
  --https-only true \
  --min-tls-version "TLS1_2"

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME

# Assign Storage Blob Data Owner role to service principal
az role assignment create \
  --assignee $SERVICE_PRINCIPAL \
  --role "Storage Blob Data Owner" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"

echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container: $CONTAINER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
```

### 3. Create Azure Container Registry

```bash
ACR_NAME="bankxacr$(date +%s | sha256sum | cut -c1-10)"
RESOURCE_GROUP="bankx-prod-rg"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku "Standard" \
  --location "East Asia" \
  --admin-enabled false

# Get login server
ACR_LOGIN_SERVER=$(az acr show \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --query loginServer \
  -o tsv)

# Get ACR credentials
ACR_USERNAME=$(az acr credential show \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --query username \
  -o tsv)

ACR_PASSWORD=$(az acr credential show \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --query passwords[0].value \
  -o tsv)

echo "ACR Name: $ACR_NAME"
echo "ACR Login Server: $ACR_LOGIN_SERVER"
echo "ACR Username: $ACR_USERNAME"
echo "ACR Password: $ACR_PASSWORD"
```

---

## GitHub Secrets Configuration

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add the following secrets:

### Azure OIDC Secrets

```
AZURE_CLIENT_ID              - (from App Registration)
AZURE_TENANT_ID              - (from Azure subscription)
AZURE_SUBSCRIPTION_ID        - (from Azure subscription)
AZURE_OIDC_TOKEN             - (auto-populated by GitHub Actions, leave empty or set to placeholder)
```

### Terraform State Secrets

```
TF_STATE_RG                  - Resource group for Terraform state (e.g., bankx-prod-rg)
TF_STATE_SA                  - Storage account name (e.g., bankxtfstate...)
TF_STATE_CONTAINER           - Container name (e.g., tfstate)
```

### Container Registry Secrets

```
ACR_NAME                     - Azure Container Registry name (e.g., bankxacr...)
ACR_LOGIN_SERVER             - ACR login server (e.g., bankxacr....azurecr.io)
ACR_USERNAME                 - ACR username
ACR_PASSWORD                 - ACR password
```

### AKS Deployment Secrets

```
AKS_RESOURCE_GROUP           - AKS resource group (e.g., bankx-prod-rg)
AKS_CLUSTER_NAME             - AKS cluster name (e.g., bankx-aks-prod)
```

### Notifications (Optional)

```
SLACK_WEBHOOK_URL            - Slack webhook for notifications (optional)
```

### Script to Add All Secrets at Once (macOS/Linux)

```bash
#!/bin/bash

# Set your values
GITHUB_TOKEN="your-github-personal-access-token"
GITHUB_OWNER="your-github-username"
GITHUB_REPO="bankx-assignment"

# Azure values
AZURE_CLIENT_ID="your-app-registration-id"
AZURE_TENANT_ID="your-tenant-id"
AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Terraform state values
TF_STATE_RG="bankx-prod-rg"
TF_STATE_SA="your-storage-account-name"
TF_STATE_CONTAINER="tfstate"

# ACR values
ACR_NAME="your-acr-name"
ACR_LOGIN_SERVER="your-acr-login-server"
ACR_USERNAME="00000000-0000-0000-0000-000000000000"
ACR_PASSWORD="your-acr-password"

# AKS values
AKS_RESOURCE_GROUP="bankx-prod-rg"
AKS_CLUSTER_NAME="bankx-aks-prod"

# Function to add secret
add_secret() {
  local SECRET_NAME=$1
  local SECRET_VALUE=$2
  
  echo "Adding secret: $SECRET_NAME"
  
  gh secret set $SECRET_NAME \
    --body "$SECRET_VALUE" \
    --repo $GITHUB_OWNER/$GITHUB_REPO
}

# Add all secrets
add_secret "AZURE_CLIENT_ID" "$AZURE_CLIENT_ID"
add_secret "AZURE_TENANT_ID" "$AZURE_TENANT_ID"
add_secret "AZURE_SUBSCRIPTION_ID" "$AZURE_SUBSCRIPTION_ID"
add_secret "TF_STATE_RG" "$TF_STATE_RG"
add_secret "TF_STATE_SA" "$TF_STATE_SA"
add_secret "TF_STATE_CONTAINER" "$TF_STATE_CONTAINER"
add_secret "ACR_NAME" "$ACR_NAME"
add_secret "ACR_LOGIN_SERVER" "$ACR_LOGIN_SERVER"
add_secret "ACR_USERNAME" "$ACR_USERNAME"
add_secret "ACR_PASSWORD" "$ACR_PASSWORD"
add_secret "AKS_RESOURCE_GROUP" "$AKS_RESOURCE_GROUP"
add_secret "AKS_CLUSTER_NAME" "$AKS_CLUSTER_NAME"

echo "✅ All secrets added successfully"
```

---

## Pipeline Overview

### 1. Terraform Infrastructure Pipeline

**File:** `.github/workflows/terraform-infrastructure.yml`

**Triggers:**
- Push to `main` or `develop` branches with changes to Terraform files
- Pull requests to `main` or `develop` with changes to Terraform files

**Steps:**
1. Checkout code
2. Setup Terraform
3. Azure OIDC Login
4. Initialize Terraform with remote backend
5. Validate Terraform configuration
6. Check Terraform formatting
7. Generate Terraform plan
8. Comment PR with plan (for pull requests)
9. Apply Terraform (only on `main` branch push)
10. Capture outputs
11. Create GitHub deployment
12. Notify Slack

**Manual Trigger:**
```bash
# You can manually trigger the workflow via GitHub API
gh workflow run terraform-infrastructure.yml --ref main
```

### 2. Node.js App Deployment Pipeline

**File:** `.github/workflows/deploy-nodejs-app.yml`

**Triggers:**
- Push to `main` or `develop` branches with changes to app code
- Pull requests to `main` or `develop` with changes to app code
- Manual workflow dispatch

**Jobs:**
1. **Build & Push Docker Image**
   - Build Docker image
   - Scan for vulnerabilities
   - Push to Azure Container Registry
   - Push latest tag

2. **Deploy to AKS**
   - Get AKS credentials
   - Verify cluster connection
   - Create/update namespace
   - Create ACR pull secret
   - Update deployment with new image
   - Wait for rollout
   - Verify deployment
   - Perform health checks
   - Get service endpoint
   - Rollback on failure
   - Notify Slack

**Manual Trigger:**
```bash
# Trigger via GitHub API
gh workflow run deploy-nodejs-app.yml \
  --ref main \
  -f force_deploy=true
```

---

## Testing the Pipelines

### Test 1: Manual Terraform Plan

```bash
# Create a test branch
git checkout -b test/terraform-plan

# Make a small Terraform change
echo "# Test comment" >> variables.tf

# Commit and push
git add variables.tf
git commit -m "test: trigger terraform plan"
git push origin test/terraform-plan

# Create Pull Request in GitHub
# Watch the workflow run
```

### Test 2: Deploy Application

```bash
# Create a test branch
git checkout -b test/app-deploy

# Make a change to the app
echo "# Test change" >> app/app.js

# Commit and push to main (or develop)
git add app/app.js
git commit -m "test: trigger app deployment"
git push origin test/app-deploy

# Create Pull Request → Merge to main
# Watch the deployment workflow
```

### Test 3: Full Infrastructure + App Deployment

```bash
# 1. Push Terraform changes
git checkout -b feature/infrastructure-update
# Make infrastructure changes
git push origin feature/infrastructure-update
# Merge to main

# 2. Push app changes
git checkout -b feature/app-update
# Make app changes
git push origin feature/app-update
# Merge to main

# Both pipelines will run
```

---

## Troubleshooting

### Issue: OIDC Authentication Fails

**Error:** `AADSTS700023: Client assertion is not within its valid time range`

**Solution:**
```bash
# Ensure your machine time is synced
# macOS
ntpdate -s time.nist.gov

# Linux
sudo timedatectl set-ntp true
```

### Issue: Terraform Plan Fails with Backend Error

**Error:** `Error: azurerm: Failed to read state`

**Solution:**
1. Verify storage account exists: `az storage account show --name $TF_STATE_SA`
2. Verify container exists: `az storage container exists --account-name $TF_STATE_SA --name $TF_STATE_CONTAINER`
3. Verify service principal has Storage Blob Data Owner role
4. Re-run the workflow

### Issue: AKS Deployment Fails - Image Pull Error

**Error:** `Failed to pull image ... imagepullbackoff`

**Solution:**
```bash
# Verify ACR credentials
az acr login --name <acr-name>

# Check image exists in ACR
az acr repository list --name <acr-name>

# Verify service principal has AcrPull role
az role assignment list \
  --assignee <service-principal-id> \
  --query "[?roleDefinitionName=='AcrPull']"
```

### Issue: Kubernetes Deployment Rollout Timeout

**Error:** `error: timed out waiting for the condition`

**Solution:**
```bash
# Check pod logs
kubectl logs -f -n nodejs-hello-ns deployment/nodejs-hello

# Check pod events
kubectl describe pod -n nodejs-hello-ns <pod-name>

# Check resource availability
kubectl describe node

# Increase rollout timeout in workflow (current: 5m)
```

### Issue: GitHub Actions Rate Limiting

**Error:** `API rate limit exceeded`

**Solution:**
1. Use `gh` CLI authentication: `gh auth login`
2. Use a GitHub App token instead of personal access token
3. Increase between API calls using `sleep`

### Issue: Slack Notifications Not Sending

**Error:** `No errors in logs but no Slack messages`

**Solution:**
```bash
# Verify webhook URL
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test message"}'

# Check GitHub Actions secret is set correctly
gh secret list --repo <owner>/<repo> | grep SLACK
```

---

## Best Practices

1. **Always use environments** - Define `production` environment in GitHub for critical deployments
2. **Use branch protection rules** - Require PR reviews before merging to `main`
3. **Enable status checks** - Require workflows to pass before merge
4. **Monitor workflow runs** - Check Actions tab regularly
5. **Rotate secrets periodically** - Especially ACR and storage account keys
6. **Use OIDC over secrets** - More secure than storing credentials
7. **Log workflow execution** - Keep artifacts for debugging
8. **Test changes in develop** - Before merging to main

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Login GitHub Action](https://github.com/Azure/login)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)

---

**Last Updated:** December 23, 2025  
**Version:** 1.0
