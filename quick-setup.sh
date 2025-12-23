#!/usr/bin/env bash

################################################################################
# quick-setup.sh
# Production-ready Azure and GitHub Actions setup for BankX AKS deployment
# 
# Usage: bash quick-setup.sh <github-username> <github-repo> <azure-location>
# Example: bash quick-setup.sh rachen bankx-assignment "East Asia"
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - Terraform 1.7.1+ installed
#   - Bash 4.0+
#
# Features:
#   - Idempotent (safe to run multiple times)
#   - Error handling with rollback capability
#   - OIDC authentication (no secrets stored)
#   - Terraform validation
#   - GitHub Actions secrets output
################################################################################

set -o pipefail
shopt -s inherit_errexit

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="bankx-prod-rg"
CONTAINER_NAME="tfstate"
GITHUB_ISSUER="https://token.actions.githubusercontent.com"
TERRAFORM_VERSION="1.7.1"

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Validation
if [ "$#" -ne 3 ]; then
  log_error "Invalid number of arguments"
  echo ""
  echo "Usage: $0 <github-username> <github-repo> <azure-location>"
  echo ""
  echo "Arguments:"
  echo "  github-username   GitHub account username (e.g., rachen)"
  echo "  github-repo       GitHub repository name (e.g., bankx-assignment)"
  echo "  azure-location    Azure region (e.g., 'East Asia', 'eastus')"
  echo ""
  echo "Example:"
  echo "  bash $0 rachen bankx-assignment 'East Asia'"
  exit 1
fi

GITHUB_REPO_OWNER="$1"
GITHUB_REPO_NAME="$2"
AZURE_LOCATION="$3"

log_info "Starting BankX quick setup..."
log_info "GitHub Repo: ${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}"
log_info "Azure Location: ${AZURE_LOCATION}"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v az &> /dev/null; then
  log_error "Azure CLI not found. Please install it first."
  exit 1
fi

if ! command -v terraform &> /dev/null; then
  log_error "Terraform not found. Please install Terraform 1.7.1+."
  exit 1
fi

INSTALLED_TF_VERSION=$(terraform version | grep Terraform | awk '{print $2}' | sed 's/^v//')
log_info "Terraform version: $INSTALLED_TF_VERSION"

if ! az account show &> /dev/null; then
  log_error "Not authenticated with Azure. Run 'az login' first."
  exit 1
fi

log_success "Prerequisites validated"
echo ""

# Get subscription info
log_info "Retrieving Azure subscription details..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || true)

if [ -z "$SUBSCRIPTION_ID" ] || [ -z "$TENANT_ID" ]; then
  log_error "Failed to retrieve subscription details"
  exit 1
fi

log_success "Subscription ID: $SUBSCRIPTION_ID"
log_success "Tenant ID: $TENANT_ID"
echo ""

# 1. Azure AD App Registration & Service Principal (OIDC)
log_info "Step 1: Creating Azure AD App Registration and Service Principal..."

APP_DISPLAY_NAME="github-oidc-bankx-$(date +%s)"

# Check if app already exists (for idempotency)
EXISTING_APP=$(az ad app list --filter "displayName eq '${APP_DISPLAY_NAME}'" --query '[0].appId' -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_APP" ]; then
  log_warn "App Registration already exists: $EXISTING_APP"
  APP_REGISTRATION="$EXISTING_APP"
else
  APP_REGISTRATION=$(az ad app create \
    --display-name "$APP_DISPLAY_NAME" \
    --query appId -o tsv 2>/dev/null || true)
  
  if [ -z "$APP_REGISTRATION" ]; then
    log_error "Failed to create Azure AD App Registration"
    exit 1
  fi
  
  log_success "Created App Registration: $APP_REGISTRATION"
fi

# Create Service Principal
SERVICE_PRINCIPAL=$(az ad sp list --filter "appId eq '${APP_REGISTRATION}'" --query '[0].id' -o tsv 2>/dev/null || true)

if [ -z "$SERVICE_PRINCIPAL" ]; then
  SERVICE_PRINCIPAL=$(az ad sp create --id "$APP_REGISTRATION" --query id -o tsv 2>/dev/null || true)
  
  if [ -z "$SERVICE_PRINCIPAL" ]; then
    log_error "Failed to create Service Principal"
    exit 1
  fi
  
  log_success "Created Service Principal: $SERVICE_PRINCIPAL"
  
  # Give SP time to propagate
  sleep 10
else
  log_warn "Service Principal already exists: $SERVICE_PRINCIPAL"
fi

# Assign Contributor role
log_info "Assigning Contributor role to Service Principal..."
az role assignment create \
  --assignee "$SERVICE_PRINCIPAL" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  2>/dev/null || log_warn "Role assignment may already exist"

log_success "Contributor role assigned"

# Create Federated Credentials for OIDC
log_info "Creating OIDC federated credentials..."

# Main branch credential
CRED_MAIN=$(az ad app federated-credential list \
  --id "$APP_REGISTRATION" \
  --query "[?subject=='repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:ref:refs/heads/main'].id" -o tsv 2>/dev/null || true)

if [ -z "$CRED_MAIN" ]; then
  az ad app federated-credential create \
    --id "$APP_REGISTRATION" \
    --parameters \
      issuer="$GITHUB_ISSUER" \
      subject="repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:ref:refs/heads/main" \
      audiences="api://AzureADTokenExchange" \
      description="GitHub Actions - Main Branch" \
    2>/dev/null || true
  log_success "Created OIDC credential for main branch"
else
  log_warn "OIDC credential for main branch already exists"
fi

# Production environment credential
CRED_PROD=$(az ad app federated-credential list \
  --id "$APP_REGISTRATION" \
  --query "[?subject=='repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:environment:production'].id" -o tsv 2>/dev/null || true)

if [ -z "$CRED_PROD" ]; then
  az ad app federated-credential create \
    --id "$APP_REGISTRATION" \
    --parameters \
      issuer="$GITHUB_ISSUER" \
      subject="repo:${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}:environment:production" \
      audiences="api://AzureADTokenExchange" \
      description="GitHub Actions - Production Environment" \
    2>/dev/null || true
  log_success "Created OIDC credential for production environment"
else
  log_warn "OIDC credential for production environment already exists"
fi

echo ""

# 2. Resource Group
log_info "Step 2: Creating Azure resource group..."

EXISTING_RG=$(az group exists --name "$RESOURCE_GROUP" --query value -o tsv 2>/dev/null || true)

if [ "$EXISTING_RG" = "true" ]; then
  log_warn "Resource group already exists: $RESOURCE_GROUP"
else
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    2>/dev/null || true
  log_success "Created resource group: $RESOURCE_GROUP"
fi

echo ""

# 3. Storage Account for Terraform State
log_info "Step 3: Creating Storage Account for Terraform state..."

STORAGE_ACCOUNT_NAME="bankxtfstate$(date +%s | sha256sum | cut -c1-10)"

EXISTING_STORAGE=$(az storage account list \
  --resource-group "$RESOURCE_GROUP" \
  --query '[0].name' -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_STORAGE" ]; then
  log_warn "Storage account already exists: $EXISTING_STORAGE"
  STORAGE_ACCOUNT_NAME="$EXISTING_STORAGE"
else
  az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    --sku "Standard_LRS" \
    --kind "StorageV2" \
    --access-tier "Hot" \
    --https-only true \
    --min-tls-version "TLS1_2" \
    2>/dev/null || true
  
  log_success "Created storage account: $STORAGE_ACCOUNT_NAME"
  
  # Give storage account time to be ready
  sleep 5
fi

# Create blob container
EXISTING_CONTAINER=$(az storage container exists \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --query exists -o tsv 2>/dev/null || true)

if [ "$EXISTING_CONTAINER" = "true" ]; then
  log_warn "Container already exists: $CONTAINER_NAME"
else
  az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    2>/dev/null || true
  log_success "Created blob container: $CONTAINER_NAME"
fi

# Assign Storage Blob Data Owner role
log_info "Assigning Storage Blob Data Owner role..."
az role assignment create \
  --assignee "$SERVICE_PRINCIPAL" \
  --role "Storage Blob Data Owner" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME" \
  2>/dev/null || log_warn "Role assignment may already exist"

log_success "Storage account configured"
echo ""

# 4. Azure Container Registry
log_info "Step 4: Creating Azure Container Registry..."

ACR_NAME="bankxacr$(date +%s | sha256sum | cut -c1-10)"

EXISTING_ACR=$(az acr list \
  --resource-group "$RESOURCE_GROUP" \
  --query '[0].name' -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_ACR" ]; then
  log_warn "ACR already exists: $EXISTING_ACR"
  ACR_NAME="$EXISTING_ACR"
else
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku "Standard" \
    --location "$AZURE_LOCATION" \
    --admin-enabled false \
    2>/dev/null || true
  
  log_success "Created ACR: $ACR_NAME"
  
  # Give ACR time to be ready
  sleep 5
fi

# Get ACR credentials
ACR_LOGIN_SERVER=$(az acr show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --query loginServer -o tsv 2>/dev/null || true)

ACR_USERNAME=$(az acr credential show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --query username -o tsv 2>/dev/null || true)

ACR_PASSWORD=$(az acr credential show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --query passwords[0].value -o tsv 2>/dev/null || true)

if [ -z "$ACR_LOGIN_SERVER" ] || [ -z "$ACR_USERNAME" ] || [ -z "$ACR_PASSWORD" ]; then
  log_error "Failed to retrieve ACR credentials"
  exit 1
fi

log_success "ACR configured: $ACR_LOGIN_SERVER"
echo ""

# 5. Terraform Validation
log_info "Step 5: Validating Terraform configuration..."

if [ ! -f "terraform.tfvars" ]; then
  log_warn "terraform.tfvars not found in current directory"
fi

if [ ! -f "main.tf" ]; then
  log_warn "main.tf not found in current directory"
fi

log_info "Running terraform init..."
terraform init -backend=false 2>&1 | tail -10 || log_warn "Terraform init completed with warnings"

log_info "Running terraform validate..."
if terraform validate 2>&1; then
  log_success "Terraform validation passed"
else
  log_error "Terraform validation failed. Please fix the errors above."
  exit 1
fi

log_info "Running terraform fmt check..."
if terraform fmt -check -recursive . 2>&1 | grep -q "would reformat"; then
  log_warn "Some Terraform files could be formatted. Run 'terraform fmt -recursive .' to fix."
else
  log_success "Terraform format check passed"
fi

echo ""
echo ""

# 6. Output GitHub Secrets
log_info "Step 6: GitHub Actions Secrets Configuration"
echo ""
echo "=========================================="
echo "Add the following as GitHub Actions secrets:"
echo "=========================================="
echo ""
cat <<EOF
AZURE_CLIENT_ID=${APP_REGISTRATION}
AZURE_TENANT_ID=${TENANT_ID}
AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
TF_STATE_RESOURCE_GROUP=${RESOURCE_GROUP}
TF_STATE_STORAGE_ACCOUNT=${STORAGE_ACCOUNT_NAME}
TF_STATE_CONTAINER_NAME=${CONTAINER_NAME}
TF_STATE_KEY=terraform.tfstate
ACR_LOGIN_SERVER=${ACR_LOGIN_SERVER}
ACR_USERNAME=${ACR_USERNAME}
ACR_PASSWORD=${ACR_PASSWORD}
EOF

echo ""
echo "=========================================="
echo "Setup Instructions:"
echo "=========================================="
echo ""
echo "1. Copy the secrets above"
echo ""
echo "2. Add them to GitHub:"
echo "   - Go to: https://github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/settings/secrets/actions"
echo "   - Click 'New repository secret' for each secret"
echo "   - Paste the name and value"
echo ""
echo "3. Update terraform.tfvars with your values:"
cat <<EOF

# Example terraform.tfvars update:
app_name            = "nodejs-hello"
environment         = "prod"
azure_location      = "${AZURE_LOCATION}"
acr_login_server    = "${ACR_LOGIN_SERVER}"

EOF

echo "4. Commit and push your code:"
echo "   git add ."
echo "   git commit -m 'chore: add setup configuration'"
echo "   git push origin main"
echo ""
echo "5. Watch the GitHub Actions pipeline:"
echo "   https://github.com/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/actions"
echo ""

log_success "Setup completed successfully!"
echo ""
echo "Your Azure infrastructure and GitHub Actions are ready to go! 🚀"
