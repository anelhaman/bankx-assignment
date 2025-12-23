# Implementation Checklist - BankX Azure Infrastructure

Complete checklist for deploying the production-grade Azure infrastructure with GitHub Actions CI/CD pipelines.

## Phase 1: Local Setup & Validation

### Development Environment
- [ ] Install Terraform (>= 1.0)
- [ ] Install Azure CLI
- [ ] Install kubectl
- [ ] Install Docker
- [ ] Install GitHub CLI
- [ ] Clone repository: `git clone ...`
- [ ] Navigate to project: `cd bankx-assignment`

### Code Validation
- [ ] Review Terraform files: `main.tf`, `variables.tf`, `outputs.tf`
- [ ] Review modules: `modules/networking`, `modules/aks`, `modules/monitoring`
- [ ] Review Kubernetes manifests: `kubernetes.tf`
- [ ] Review GitHub Actions workflows: `.github/workflows/*.yml`
- [ ] Review Node.js app: `app/app.js`, `Dockerfile`
- [ ] Check syntax: `terraform fmt -check -recursive`
- [ ] Validate: `terraform validate`

### Documentation Review
- [ ] Read [README.md](README.md)
- [ ] Read [QUICKSTART.md](QUICKSTART.md)
- [ ] Read [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
- [ ] Read [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

---

## Phase 2: Azure Account Setup

### Azure CLI Login
- [ ] Login to Azure: `az login`
- [ ] Set subscription: `az account set --subscription <id>`
- [ ] Verify subscription: `az account show`
- [ ] Get subscription ID (for GitHub secrets)

### Create Resource Groups
- [ ] Create main RG: `bankx-prod-rg`
- [ ] Create state RG: `bankx-state-rg` (optional, different RG is safer)
- [ ] Verify RGs: `az group list --query "[?contains(name, 'bankx')]"`

### Create Terraform State Backend
- [ ] Create storage account for state
- [ ] Create blob container `tfstate`
- [ ] Assign permissions to service principal
- [ ] Note credentials for GitHub secrets:
  - `TF_STATE_RG`
  - `TF_STATE_SA`
  - `TF_STATE_CONTAINER`

### Create Service Principal for GitHub OIDC
- [ ] Create app registration
- [ ] Create service principal
- [ ] Add federated credentials (main branch)
- [ ] Add federated credentials (production environment)
- [ ] Assign Contributor role
- [ ] Note credentials for GitHub secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

### Create Azure Container Registry
- [ ] Create ACR resource
- [ ] Enable admin access (for GitHub Actions)
- [ ] Get admin credentials
- [ ] Note credentials for GitHub secrets:
  - `ACR_NAME`
  - `ACR_LOGIN_SERVER`
  - `ACR_USERNAME`
  - `ACR_PASSWORD`

---

## Phase 3: GitHub Repository Setup

### Repository Configuration
- [ ] Fork or clone repository
- [ ] Enable GitHub Actions
- [ ] Create `main` branch (default)
- [ ] Create `develop` branch
- [ ] Review branch protection rules

### GitHub Secrets Configuration

**Method 1: GitHub UI (Manual)**
1. Go to Settings → Secrets and variables → Actions
2. Add each secret individually

**Method 2: GitHub CLI**
```bash
gh secret set SECRET_NAME --body "value" --repo owner/repo
```

**Required Secrets:**
- [ ] `AZURE_CLIENT_ID`
- [ ] `AZURE_TENANT_ID`
- [ ] `AZURE_SUBSCRIPTION_ID`
- [ ] `TF_STATE_RG`
- [ ] `TF_STATE_SA`
- [ ] `TF_STATE_CONTAINER`
- [ ] `ACR_NAME`
- [ ] `ACR_LOGIN_SERVER`
- [ ] `ACR_USERNAME`
- [ ] `ACR_PASSWORD`
- [ ] `AKS_RESOURCE_GROUP`
- [ ] `AKS_CLUSTER_NAME`
- [ ] `SLACK_WEBHOOK_URL` (optional)

### GitHub Environments
- [ ] Create `production` environment
- [ ] (Optional) Add required reviewers
- [ ] (Optional) Add deployment branches
- [ ] (Optional) Add secrets specific to environment

### Branch Protection Rules
- [ ] Require PR reviews (recommend 1+)
- [ ] Require status checks to pass
- [ ] Require workflow runs to pass
- [ ] Dismiss stale reviews
- [ ] Block force pushes to main

---

## Phase 4: Pre-Deployment Testing

### Terraform Validation
```bash
- [ ] terraform init -upgrade
- [ ] terraform validate
- [ ] terraform fmt -check -recursive
- [ ] terraform plan -var-file="terraform.tfvars"
```

### Docker Build Test
```bash
- [ ] docker build -t test:latest .
- [ ] docker run --rm -p 3000:3000 test:latest
- [ ] curl http://localhost:3000
- [ ] Verify "Hello World" response
```

### Kubernetes Manifests Validation
- [ ] Check Kubernetes YAML syntax: `kubernetes.tf`
- [ ] Verify pod specs
- [ ] Verify service specs
- [ ] Verify ingress specs

### GitHub Actions Workflow Validation
- [ ] Review `.github/workflows/terraform-infrastructure.yml`
- [ ] Review `.github/workflows/deploy-nodejs-app.yml`
- [ ] Check trigger conditions
- [ ] Verify step order
- [ ] Check error handling

---

## Phase 5: Initial Deployment

### Option A: GitHub Actions Deployment (Recommended)

```bash
- [ ] Create feature branch: git checkout -b feature/initial-deploy
- [ ] Commit code: git add . && git commit -m "Initial deployment"
- [ ] Push branch: git push origin feature/initial-deploy
- [ ] Create Pull Request in GitHub
- [ ] Review PR and plan output
- [ ] Approve and merge to main
- [ ] Watch GitHub Actions workflows run
```

### Option B: Manual Terraform Deployment

```bash
- [ ] Initialize Terraform:
      terraform init \
        -backend-config="resource_group_name=$TF_STATE_RG" \
        -backend-config="storage_account_name=$TF_STATE_SA" \
        -backend-config="container_name=$TF_STATE_CONTAINER" \
        -backend-config="key=terraform.tfstate"

- [ ] Verify plan: terraform plan -var-file="terraform.tfvars"
- [ ] Apply changes: terraform apply -var-file="terraform.tfvars"
- [ ] Note outputs: terraform output
```

### Deployment Verification
```bash
- [ ] Check Terraform apply succeeded
- [ ] Verify resources in Azure Portal
- [ ] Check resource group: bankx-prod-rg
- [ ] Check VNet, subnets, NSGs
- [ ] Check AKS cluster status
- [ ] Check ACR creation
- [ ] Check Log Analytics workspace
```

---

## Phase 6: Post-Deployment Configuration

### Get AKS Credentials
```bash
- [ ] az aks get-credentials \
        --resource-group bankx-prod-rg \
        --name bankx-aks-prod
- [ ] Verify kubeconfig: kubectl config current-context
```

### Verify Kubernetes Cluster
```bash
- [ ] Check nodes: kubectl get nodes
- [ ] Check namespaces: kubectl get ns
- [ ] Check pods: kubectl get pods -A
- [ ] Check services: kubectl get svc -A
```

### Deploy Application via GitHub Actions
```bash
- [ ] Create feature branch: git checkout -b feature/app-deploy
- [ ] Ensure app files present: app/, package.json, Dockerfile
- [ ] Commit code: git add . && git commit -m "Deploy app"
- [ ] Push branch: git push origin feature/app-deploy
- [ ] Create and merge PR
- [ ] Watch app deployment pipeline
```

### Verify Application Deployment
```bash
- [ ] Check pods: kubectl get pods -n nodejs-hello-ns
- [ ] Check deployments: kubectl get deployment -n nodejs-hello-ns
- [ ] Check services: kubectl get svc -n nodejs-hello-ns
- [ ] Check logs: kubectl logs -f deployment/nodejs-hello -n nodejs-hello-ns
- [ ] Test app: curl http://<app-gateway-ip>/
```

---

## Phase 7: Monitoring & Logging Verification

### Check Monitoring Resources
- [ ] Log Analytics Workspace created
- [ ] Application Insights created
- [ ] Monitor Alert Group created

### Verify Logs Flowing
```bash
- [ ] AKS logs in Log Analytics
- [ ] Container logs in Log Analytics
- [ ] Application Insights tracking requests
- [ ] Custom metrics being recorded
```

### Check Dashboards & Alerts
- [ ] Application Insights dashboard accessible
- [ ] Log Analytics Workspace accessible
- [ ] Alerts configured
- [ ] Slack notifications working (if configured)

---

## Phase 8: Load Testing & Scaling Verification

### Test Horizontal Pod Autoscaling
```bash
- [ ] Deploy load generator (optional)
- [ ] Monitor HPA: kubectl get hpa -n nodejs-hello-ns -w
- [ ] Verify pod scaling up: kubectl get pods -n nodejs-hello-ns -w
- [ ] Verify pod scaling down after load stops
```

### Test Node Autoscaling
```bash
- [ ] Monitor nodes: kubectl top nodes -w
- [ ] Check if new nodes provision when needed
- [ ] Check if nodes scale down when not needed
```

### Test Health Checks
```bash
- [ ] Kill a pod: kubectl delete pod <pod> -n nodejs-hello-ns
- [ ] Verify new pod starts
- [ ] Check logs for restart reason
```

---

## Phase 9: Security & Compliance Verification

### Network Security
- [ ] AKS nodes not internet-exposed
- [ ] NSGs configured correctly
- [ ] Network policies in place
- [ ] Ingress through App Gateway only

### Identity & Access
- [ ] OIDC authentication working
- [ ] No secrets in Terraform code
- [ ] Managed identities assigned
- [ ] RBAC roles correctly scoped

### Container Security
- [ ] Pods running as non-root (check `app.js` startup)
- [ ] Resource limits enforced
- [ ] Security context configured
- [ ] Image scanning completed

### Audit & Compliance
- [ ] AKS logs enabled
- [ ] Container logs flowing
- [ ] Metrics being recorded
- [ ] Alerts configured

---

## Phase 10: Documentation & Handover

### Documentation
- [ ] Update README.md with your Azure values
- [ ] Document any customizations made
- [ ] Document access procedures for team
- [ ] Document scaling policies
- [ ] Document monitoring dashboards

### Team Handover
- [ ] Share GitHub repository access
- [ ] Share Azure Portal access
- [ ] Share on-call procedures
- [ ] Share runbooks for common issues
- [ ] Schedule training session

### Backup & Recovery
- [ ] Document Terraform state backend
- [ ] Verify state backups enabled
- [ ] Document disaster recovery procedure
- [ ] Test restore process
- [ ] Document resource dependencies

---

## Phase 11: Production Readiness

### Final Checklist
- [ ] All resources created and healthy
- [ ] All pods running and healthy
- [ ] Application accessible and responding
- [ ] Monitoring and logging working
- [ ] Alerts configured
- [ ] Scaling policies tested
- [ ] Disaster recovery tested
- [ ] Documentation complete
- [ ] Team trained
- [ ] Go/No-Go meeting completed

### Sign-Off
- [ ] Infrastructure team sign-off
- [ ] Security team sign-off
- [ ] Operations team sign-off
- [ ] Business team sign-off

---

## Phase 12: Post-Launch Monitoring (First 24-48 Hours)

### Intensive Monitoring
- [ ] Monitor pod restarts
- [ ] Monitor node health
- [ ] Monitor memory/CPU usage
- [ ] Monitor error rates
- [ ] Monitor request latency
- [ ] Monitor disk usage

### Tuning (If Needed)
- [ ] Adjust resource requests/limits
- [ ] Adjust HPA thresholds
- [ ] Adjust node pool size
- [ ] Adjust logging verbosity
- [ ] Adjust alert thresholds

### Issue Resolution
- [ ] Address any alerts
- [ ] Fix any performance issues
- [ ] Document lessons learned
- [ ] Update runbooks

---

## Rollback Procedures

### If Infrastructure Deployment Fails
```bash
- [ ] Check workflow logs in GitHub Actions
- [ ] Review Terraform error messages
- [ ] Run: terraform plan -destroy
- [ ] Review destroy plan
- [ ] Run: terraform destroy -auto-approve (if needed)
- [ ] Investigate root cause
- [ ] Fix and re-deploy
```

### If Application Deployment Fails
```bash
- [ ] Check pod status: kubectl get pods -n nodejs-hello-ns
- [ ] Check logs: kubectl logs <pod> -n nodejs-hello-ns
- [ ] Check events: kubectl describe pod <pod> -n nodejs-hello-ns
- [ ] Workflow auto-rollback may occur
- [ ] If needed: kubectl rollout undo deployment/nodejs-hello -n nodejs-hello-ns
- [ ] Investigate and fix
- [ ] Re-deploy via GitHub Actions
```

### If Complete Rollback Needed
```bash
- [ ] Stop GitHub Actions workflows
- [ ] Destroy via Terraform: terraform destroy -auto-approve
- [ ] Verify all resources deleted
- [ ] Document incident
- [ ] Review and fix root cause
- [ ] Re-deploy following checklist
```

---

## Maintenance Schedule

### Daily
- [ ] Monitor dashboards
- [ ] Check for pod crashes
- [ ] Check error logs

### Weekly
- [ ] Review performance metrics
- [ ] Check for unused resources
- [ ] Update dependencies
- [ ] Review security logs

### Monthly
- [ ] Review costs
- [ ] Optimize resource allocation
- [ ] Test disaster recovery
- [ ] Update runbooks
- [ ] Team knowledge sharing

### Quarterly
- [ ] Major version updates
- [ ] Security audits
- [ ] Capacity planning
- [ ] Architecture review

---

## Troubleshooting Quick Links

| Issue | Reference |
|-------|-----------|
| OIDC auth fails | [GITHUB_ACTIONS_SETUP.md - Troubleshooting](GITHUB_ACTIONS_SETUP.md#troubleshooting) |
| Terraform fails | [GITHUB_ACTIONS_SETUP.md - Troubleshooting](GITHUB_ACTIONS_SETUP.md#troubleshooting) |
| Pod not starting | [README.md - Troubleshooting](README.md#troubleshooting) |
| App not accessible | [QUICKSTART.md - Troubleshooting](QUICKSTART.md#12-troubleshooting) |
| Monitoring issues | [README.md - View Metrics](README.md#view-metrics-in-azure-monitor) |

---

## Sign-Off

**Date:** _______________

**Infrastructure Team:** _________________ (Signature)

**Security Team:** _________________ (Signature)

**Operations Team:** _________________ (Signature)

**Business Owner:** _________________ (Signature)

---

**Status:** Ready for Production  
**Version:** 1.0  
**Last Updated:** December 23, 2025
