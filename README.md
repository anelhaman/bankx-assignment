# BankX - AKS Deployment

## 📖 Documentation

**See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for complete instructions**

## Quick Deploy

```bash
# 1. Set environment variables
set -x ARM_CLIENT_ID (grep AZURE_CLIENT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_TENANT_ID (grep AZURE_TENANT_ID azure-secrets.txt | cut -d= -f2)
set -x ARM_SUBSCRIPTION_ID (grep AZURE_SUBSCRIPTION_ID azure-secrets.txt | cut -d= -f2)

# 2. Deploy
terraform apply -var-file="terraform.tfvars"
```

**Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for full instructions.**
