data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.log_analytics_workspace_name}-${data.azurerm_client_config.current.subscription_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "main" {
  name                = "${var.app_name}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "main" {
  name                = "${var.app_name}-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "appxalert"
  tags                = var.tags
}

resource "azurerm_monitor_metric_alert" "request_count" {
  name                = "${var.app_name}-request-count-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when request count exceeds threshold"
  severity            = 3

  criteria {
    metric_namespace       = "Microsoft.Insights/components"
    metric_name            = "requests/count"
    operator               = "GreaterThan"
    threshold              = 1000
    aggregation            = "Count"
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  enabled = true
  tags    = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  count                      = var.aks_cluster_id != "" ? 1 : 0
  name                       = "${var.app_name}-aks-diagnostics"
  target_resource_id         = var.aks_cluster_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

}

resource "azurerm_monitor_diagnostic_setting" "app_insights" {
  name                       = "${var.app_name}-appinsights-diagnostics"
  target_resource_id         = azurerm_application_insights.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppTraces"
  }

}

resource "azurerm_log_analytics_saved_search" "request_metrics" {
  name                       = "${var.app_name}-request-metrics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "App Metrics"
  display_name               = "Request Count Metrics"
  query                      = <<-QUERY
    requests
    | summarize RequestCount = count() by bin(timestamp, 1m), name
    | extend MetricName = "RequestCount", MetricValue = RequestCount
  QUERY
}

resource "azurerm_log_analytics_saved_search" "app_logs" {
  name                       = "${var.app_name}-app-logs"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  category                   = "App Logs"
  display_name               = "Application Container Logs"
  query                      = <<-QUERY
    ContainerLog
    | where Pod contains "${var.app_name}"
    | project TimeGenerated, Pod, ContainerID, LogEntry
    | order by TimeGenerated desc
  QUERY
}
