environment                  = "prod"
location                     = "East Asia"
resource_group_name          = "bankx-prod-rg"
vnet_name                    = "bankx-prod-vnet"
vnet_address_space           = ["10.0.0.0/16"]
public_subnet_name           = "bankx-public-subnet"
public_subnet_address_space  = "10.0.1.0/24"
private_subnet_name          = "bankx-private-subnet"
private_subnet_address_space = "10.0.2.0/24"
aks_cluster_name             = "bankx-aks-prod"
aks_node_count               = 2
aks_vm_size                  = "Standard_B2s"
app_gateway_name             = "bankx-appgw-prod"
log_analytics_workspace_name = "bankx-logs-prod"
log_analytics_retention_days = 30
app_name                     = "nodejs-hello"
kubernetes_version           = "1.28"
network_plugin               = "azure"

tags = {
  Environment = "production"
  Project     = "BankX"
  ManagedBy   = "Terraform"
  CreatedDate = "2025-12-23"
  Owner       = "DevOps"
  CostCenter  = "Engineering"
}
