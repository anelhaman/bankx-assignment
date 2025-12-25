data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "aks" {
  resource_group_name = var.resource_group_name
  location            = var.location
  name                = "${var.aks_cluster_name}-identity"
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.aks_cluster_name}-dns"

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = var.private_subnet_id

    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }

    tags = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = var.network_plugin
    network_policy      = "azure"
    dns_service_ip      = "10.1.0.10"
    service_cidr        = "10.1.0.0/16"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "aks_subnet" {
  scope              = var.private_subnet_id
  role_definition_name = "Network Contributor"
  principal_id       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_container_registry" "main" {
  name                = replace(lower("${var.aks_cluster_name}acr"), "-", "")
  location            = var.location
  resource_group_name = var.resource_group_name
  admin_enabled       = true
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_pull_images" {
  scope              = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
