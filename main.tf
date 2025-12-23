terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# Get current Azure subscription context
data "azurerm_client_config" "current" {}

# Networking Module
module "networking" {
  source = "./modules/networking"

  environment                  = var.environment
  location                     = var.location
  resource_group_name          = var.resource_group_name
  vnet_name                    = var.vnet_name
  vnet_address_space           = var.vnet_address_space
  public_subnet_name           = var.public_subnet_name
  public_subnet_address_space  = var.public_subnet_address_space
  private_subnet_name          = var.private_subnet_name
  private_subnet_address_space = var.private_subnet_address_space
  tags                         = var.tags
}

# Monitoring Module (created first so it can be referenced by AKS)
module "monitoring" {
  source = "./modules/monitoring"

  environment                  = var.environment
  location                     = var.location
  resource_group_name          = module.networking.resource_group_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_retention_days = var.log_analytics_retention_days
  app_name                     = var.app_name
  aks_cluster_id               = "" # Will be updated after AKS creation
  tags                         = var.tags

  depends_on = [module.networking]
}

# AKS Module
module "aks" {
  source = "./modules/aks"

  environment                = var.environment
  location                   = var.location
  resource_group_name        = module.networking.resource_group_name
  aks_cluster_name           = var.aks_cluster_name
  aks_node_count             = var.aks_node_count
  aks_vm_size                = var.aks_vm_size
  kubernetes_version         = var.kubernetes_version
  network_plugin             = var.network_plugin
  private_subnet_id          = module.networking.private_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = var.tags

  depends_on = [module.networking, module.monitoring]
}

# Update monitoring module with AKS cluster ID (due to circular dependency)
module "monitoring_update" {
  source = "./modules/monitoring"

  environment                  = var.environment
  location                     = var.location
  resource_group_name          = module.networking.resource_group_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_retention_days = var.log_analytics_retention_days
  app_name                     = var.app_name
  aks_cluster_id               = module.aks.aks_cluster_id
  tags                         = var.tags

  depends_on = [module.aks]
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.aks.kube_config[0].host
  client_certificate     = base64decode(module.aks.kube_config[0].client_certificate)
  client_key             = base64decode(module.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config[0].cluster_ca_certificate)
}
