#!/usr/bin/env bash
set -euo pipefail

################################################################################
# azure-setup.sh
# Minimal Azure prerequisites setup for Terraform deployment
# Creates: Service Principal + OIDC + Resource Group
# Terraform creates: Storage, ACR, AKS, etc.
################################################################################

# Config
RESOURCE_GROUP="bankx-prod-rg"
AZURE_LOCATION="${AZURE_LOCATION:-East Asia}"
GITHUB_ISSUER="https://token.actions.githubusercontent.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v az &>/dev/null || { log_error "Azure CLI not found"; return 1; }
    [[ -n "${GITHUB_REPO_OWNER:-}" ]] || { log_error "GITHUB_REPO_OWNER not set"; return 1; }
    [[ -n "${GITHUB_REPO_NAME:-}" ]] || { log_error "GITHUB_REPO_NAME not set"; return 1; }
    az account show &>/dev/null || { log_error "Not logged into Azure"; return 1; }
    
    log_success "Prerequisites check passed"
}

# Create resource group
create_resource_group() {
    log_info "Creating resource group: $RESOURCE_GROUP"
    
    if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        log_warn "Resource group already exists"
    else
        az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" --tags environment=production project=bankx
        log_success "Resource group created"
    fi
}

# Create Service Principal
create_service_principal() {
    log_info "Creating Service Principal for GitHub OIDC..."
    
    local APP_NAME="github-oidc-bankx"
    local APP_ID
    APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$APP_ID" ]]; then
        log_warn "App registration already exists: $APP_ID"
    else
        APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
        log_success "App registration created: $APP_ID"
    fi
    
    local SP_ID
    SP_ID=$(az ad sp list --display-name "$APP_NAME" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$SP_ID" ]]; then
        log_warn "Service Principal already exists: $SP_ID"
    else
        SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
        log_success "Service Principal created: $SP_ID"
    fi
    
    export AZURE_CLIENT_ID="$APP_ID"
    export SERVICE_PRINCIPAL_ID="$SP_ID"
}

# Assign Contributor role
assign_contributor_role() {
    log_info "Assigning Contributor role..."
    
    local SUBSCRIPTION_ID
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    az role assignment create \
        --assignee "$SERVICE_PRINCIPAL_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        2>/dev/null || log_warn "Role may already exist"
    
    log_success "Contributor role assigned"
}

# Create OIDC credentials
create_oidc_credentials() {
    log_info "Creating OIDC federated credentials..."
    
    # Main branch
    az ad app federated-credential create \
        --id "$AZURE_CLIENT_ID" \
        --parameters "{\"name\":\"github-main\",\"issuer\":\"$GITHUB_ISSUER\",\"subject\":\"repo:$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"],\"description\":\"GitHub Actions - Main\"}" \
        2>/dev/null && log_success "Main branch credential created" || log_warn "Main credential may exist"
    
    # Production
    az ad app federated-credential create \
        --id "$AZURE_CLIENT_ID" \
        --parameters "{\"name\":\"github-prod\",\"issuer\":\"$GITHUB_ISSUER\",\"subject\":\"repo:$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME:environment:production\",\"audiences\":[\"api://AzureADTokenExchange\"],\"description\":\"GitHub Actions - Production\"}" \
        2>/dev/null && log_success "Production credential created" || log_warn "Production credential may exist"
}

# Save secrets
save_secrets() {
    local SUBSCRIPTION_ID
    local TENANT_ID
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    cat > azure-secrets.txt <<EOF
# GitHub Secrets - Add these to your repository
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AKS_RESOURCE_GROUP=$RESOURCE_GROUP
EOF
    
    log_success "Secrets saved to: azure-secrets.txt"
}

# Display summary
display_summary() {
    local SUBSCRIPTION_ID
    local TENANT_ID
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    echo ""
    log_success "=== Azure Prerequisites Complete ==="
    echo ""
    echo "GitHub Secrets to add:"
    echo "  AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
    echo "  AZURE_TENANT_ID=$TENANT_ID"
    echo "  AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
    echo "  AKS_RESOURCE_GROUP=$RESOURCE_GROUP"
    echo ""
    echo "Next steps:"
    echo "  1. Add these secrets to GitHub repository settings"
    echo "  2. Update terraform.tfvars with your values"
    echo "  3. Run: terraform init"
    echo "  4. Run: terraform apply"
    echo ""
}

# Main
main() {
    log_info "Starting Azure prerequisites setup..."
    echo ""
    
    check_prerequisites || return 1
    create_resource_group
    create_service_principal
    assign_contributor_role
    create_oidc_credentials
    save_secrets
    display_summary
    
    log_success "Azure setup completed!"
}

main "$@"
