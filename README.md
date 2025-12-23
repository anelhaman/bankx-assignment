# Production-Grade Terraform for Azure - BankX Project

This Terraform configuration deploys a complete, production-grade infrastructure on Azure with automated CI/CD pipelines using GitHub Actions.

## Quick Links

- **Infrastructure Setup:** See [README.md](#usage) below
- **CI/CD Pipelines:** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for detailed setup instructions
- **Terraform Modules:** See [modules/](modules/) directory

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│          Azure Cloud Platform                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │   Virtual Network (VNet): 10.0.0.0/16       │  │
│  │                                              │  │
│  │  ┌────────────────────┐  ┌────────────────┐ │  │
│  │  │  Public Subnet     │  │ Private Subnet │ │  │
│  │  │  10.0.1.0/24       │  │  10.0.2.0/24   │ │  │
│  │  │                    │  │                │ │  │
│  │  │ ┌──────────────┐  │  │  ┌──────────┐ │ │  │
│  │  │ │ Application  │  │  │  │   AKS    │ │ │  │
│  │  │ │  Gateway     │  │  │  │ Cluster  │ │ │  │
│  │  │ │ (Public IP)  │  │  │  │          │ │ │  │
│  │  │ └──────────────┘  │  │  │ Node.js  │ │ │  │
│  │  │                    │  │  │   App    │ │ │  │
│  │  └────────────────────┘  │  └──────────┘ │ │  │
│  │                          │                │ │  │
│  └──────────────────────────┴────────────────┘ │  │
│                                                 │  │
│  ┌──────────────────────────────────────────┐  │  │
│  │  Monitoring & Logging                    │  │  │
│  │  • Log Analytics Workspace               │  │  │
│  │  • Application Insights                  │  │  │
│  │  • Azure Monitor (Metrics & Alerts)      │  │  │
│  └──────────────────────────────────────────┘  │  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Features Implemented

### 1. **Virtual Network with Public & Private Subnets**
   - VNet: `10.0.0.0/16`
   - Public Subnet: `10.0.1.0/24` (for Application Gateway)
   - Private Subnet: `10.0.2.0/24` (for AKS)
   - Network Security Groups (NSGs) for both subnets
   - Proper ingress/egress rules for security

### 2. **Azure Kubernetes Service (AKS)**
   - Deployed in private subnet for security
   - Auto-scaling enabled (2-5 nodes)
   - Network plugin: Azure CNI
   - Managed by User-Assigned Identity
   - Integrated with Log Analytics for monitoring

### 3. **Application Gateway**
   - Deployed in public subnet
   - Standard_v2 tier for production
   - Routes traffic to AKS services
   - Kubernetes Ingress controller integration
   - Static public IP for external access

### 4. **Log Analytics Workspace**
   - Centralized logging for all resources
   - 30-day retention (configurable)
   - Collects AKS cluster logs and container logs
   - Integrated with Application Insights

### 5. **Azure Monitor & Metrics**
   - Application Insights for request monitoring
   - Custom metric for request count tracking
   - Diagnostic settings for AKS cluster logs
   - Alert configuration for request thresholds
   - Saved queries for easy log analysis

### 6. **Node.js Application**
   - Lightweight Alpine-based image
   - Single route: `GET /` returns "Hello World"
   - Deployed on AKS with 2 replicas
   - Auto-scaling based on CPU/Memory (2-10 replicas)
   - Health checks (liveness & readiness probes)
   - NetworkPolicy for pod security

## Files Structure

## Files Structure

- `main.tf` - Core infrastructure using modules
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values for resource references
- `app_gateway.tf` - Application Gateway and Kubernetes Ingress
- `monitoring.tf` - Monitoring module reference
- `kubernetes.tf` - AKS deployments, services, and Node.js app
- `terraform.tfvars` - Production values
- `package.json` - Node.js app dependencies
- `app/app.js` - Node.js application code
- `Dockerfile` - Container image definition
- `.dockerignore` - Docker build exclusions
- `modules/` - Reusable Terraform modules
  - `modules/networking/` - VNet, subnets, NSGs
  - `modules/aks/` - AKS cluster and ACR
  - `modules/monitoring/` - Log Analytics and monitoring
- `.github/workflows/` - GitHub Actions pipelines
  - `.github/workflows/terraform-infrastructure.yml` - Infrastructure CI/CD
  - `.github/workflows/deploy-nodejs-app.yml` - App deployment CI/CD
- `GITHUB_ACTIONS_SETUP.md` - CI/CD setup guide
- `README.md` - This file

## Prerequisites

1. **Azure Account**: Active Azure subscription
2. **Terraform**: Version 1.0 or higher
3. **Azure CLI**: For Kubernetes access
4. **kubectl**: For managing AKS resources

```bash
# Install Azure CLI
brew install azure-cli  # macOS
# or use: choco install azure-cli  # Windows

# Install kubectl
brew install kubectl  # macOS

# Login to Azure
az login
```

## Usage

### Initialize Terraform

```bash
terraform init
```

### Plan the Deployment

```bash
terraform plan -out=tfplan
```

### Apply the Configuration

```bash
terraform apply tfplan
```

### Configure kubectl Access

After deployment, configure kubectl to access the AKS cluster:

```bash
az aks get-credentials --resource-group bankx-prod-rg --name bankx-aks-prod
```

Verify connection:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Access the Application

Get the Application Gateway public IP:

```bash
terraform output application_gateway_public_ip
```

Access the app:

```bash
curl http://<GATEWAY_PUBLIC_IP>/
# Returns: Hello World
```

### View Application Logs

#### Through Azure Portal
1. Go to Log Analytics Workspace
2. Run KQL queries to view application logs

#### Through kubectl
```bash
kubectl logs -n nodejs-hello-ns deployment/nodejs-hello
kubectl logs -f deployment/nodejs-hello -n nodejs-hello-ns
```

#### Through Azure CLI
```bash
az monitor log-analytics query \
  --workspace bankx-logs-prod \
  --analytics-query "ContainerLog | where Pod contains 'nodejs' | head 100"
```

### View Metrics in Azure Monitor

1. Navigate to Application Insights resource
2. View "Requests" metric
3. Set up custom alerts for request count thresholds
4. Monitor CPU and memory usage

### View Custom Metrics

```bash
# Query request count through Log Analytics
az monitor metrics list \
  --resource "bankx-aks-prod" \
  --metric "RequestCount"
```

## Security Features

- **Network Security**: NSGs restrict traffic to necessary ports only
- **AKS in Private Subnet**: Nodes not exposed to the internet
- **RBAC**: User-assigned identities for resource access
- **NetworkPolicy**: Pod-to-pod communication restrictions
- **Pod Security**: Non-root users, read-only filesystems
- **Resource Limits**: CPU/Memory constraints on containers
- **Health Checks**: Liveness and readiness probes

## Scaling

### Auto-Scaling AKS Nodes

```bash
# Check current autoscaler settings
kubectl get hpa -n nodejs-hello-ns

# Check node scaling
kubectl get nodes
```

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment nodejs-hello -n nodejs-hello-ns --replicas=5

# Scale cluster nodes (if needed)
az aks nodepool scale \
  --resource-group bankx-prod-rg \
  --cluster-name bankx-aks-prod \
  --name default \
  --node-count 3
```

## Monitoring & Observability

### Log Queries

#### Request Count by Hour
```kusto
requests
| summarize RequestCount = count() by bin(timestamp, 1h)
| render timechart
```

#### Application Errors
```kusto
traces
| where severityLevel >= 2
| summarize ErrorCount = count() by tostring(severityLevel)
```

#### Pod Logs
```kusto
ContainerLog
| where Namespace == "nodejs-hello-ns"
| project TimeGenerated, Pod, LogEntry
| order by TimeGenerated desc
```

## Cost Optimization

1. **VM Size**: Uses `Standard_B2s` (burstable) - suitable for testing/small workloads
   - For production: Consider `Standard_D2s_v3` or higher
2. **Node Count**: Starts with 2, auto-scales to 5
   - Adjust `min_count` and `max_count` based on workload
3. **Log Retention**: 30 days (configurable in `terraform.tfvars`)
4. **Auto-shutdown**: Not enabled; add if running dev/test only

## Customization

### Change Variables

Edit `terraform.tfvars`:

```hcl
# Example: Use different region
location = "West Europe"

# Example: Change node count
aks_node_count = 3

# Example: Increase VM size
aks_vm_size = "Standard_D2s_v3"
```

### Update Application

Replace the Node.js app in `kubernetes.tf` deployment spec with your own container image:

```hcl
container {
  image = "your-registry/your-app:latest"  # Use your container image
  # ... rest of configuration
}
```

## CI/CD Pipelines

This project includes two automated GitHub Actions pipelines:

### 1. Infrastructure Pipeline (Terraform)
- **Trigger:** Changes to `.tf` files or `terraform.tfvars`
- **Actions:** Plan → Review → Apply
- **Features:**
  - OIDC authentication to Azure
  - Terraform remote state in Azure Storage
  - PR comments with plan summaries
  - Automatic apply on main branch
  - Slack notifications
  - GitHub deployments

**Setup:** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

### 2. Application Deployment Pipeline (Docker + AKS)
- **Trigger:** Changes to app code or Dockerfile
- **Actions:** Build image → Push to ACR → Deploy to AKS
- **Features:**
  - Multi-stage Docker builds
  - Image vulnerability scanning
  - Automatic rollout and health checks
  - Automatic rollback on failure
  - Slack notifications
  - Pod logs and diagnostics

**Setup:** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

---

## Cleanup

Remove all resources:

```bash
terraform destroy
```

**Note:** If using GitHub Actions, the pipelines will automatically manage your infrastructure. Manual cleanup is only needed when disabling CI/CD.

## Troubleshooting

### AKS Connection Issues

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes

# Check node status
kubectl describe nodes
```

### Pod Not Running

```bash
# Check pod status
kubectl describe pod <pod-name> -n nodejs-hello-ns

# View logs
kubectl logs <pod-name> -n nodejs-hello-ns

# Check events
kubectl get events -n nodejs-hello-ns
```

### Application Gateway Issues

```bash
# Check backend pool health
az network application-gateway probe show \
  --resource-group bankx-prod-rg \
  --gateway-name bankx-appgw-prod

# Check if backend is healthy
kubectl get svc -n nodejs-hello-ns
```

## Production Best Practices Applied

✓ Infrastructure as Code (Terraform)
✓ Secure networking (private AKS, NSGs)
✓ High availability (multiple replicas, auto-scaling)
✓ Monitoring and alerting (Application Insights, Log Analytics)
✓ Centralized logging (Log Analytics Workspace)
✓ Resource limits and health checks
✓ Pod security policies
✓ Proper RBAC and identities
✓ Tagging and resource organization
✓ Documented and maintainable code

## Support & Documentation

- [Azure Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Kubernetes Terraform Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Application Gateway Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/)

---

**Last Updated**: December 23, 2025
**Version**: 1.0
**Status**: Production-Ready
# bankx-assignment
