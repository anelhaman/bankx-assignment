resource "azurerm_application_gateway" "main" {
  name                = var.app_gateway_name
  location            = var.location
  resource_group_name = module.networking.resource_group_name
  tags                = var.tags

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 5
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = module.networking.public_subnet_id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = module.networking.appgw_public_ip_id
  }

  backend_address_pool {
    name = "aks-backend-pool"
  }

  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = "health-probe"
  }

  probe {
    name                                = "health-probe"
    protocol                            = "Http"
    path                                = "/health"
    port                                = 80
    interval                            = 30
    timeout                             = 30
    unhealthy_threshold                 = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  depends_on = [module.networking]
}
