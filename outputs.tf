
output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.networking.resource_group_id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.networking.resource_group_name
}

output "virtual_network_id" {
  description = "ID of the Virtual Network"
  value       = module.networking.virtual_network_id
}

output "virtual_network_name" {
  description = "Name of the Virtual Network"
  value       = module.networking.virtual_network_name
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.networking.private_subnet_id
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.aks_cluster_id
  sensitive   = false
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.aks_cluster_fqdn
}

output "aks_kube_config_raw" {
  description = "Raw kubeconfig for AKS cluster"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Kube config for kubectl access"
  value       = module.aks.kube_config
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_id" {
  description = "ID of the Application Insights resource"
  value       = module.monitoring.application_insights_id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key for Application Insights"
  value       = module.monitoring.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_app_id" {
  description = "App ID for Application Insights"
  value       = module.monitoring.application_insights_app_id
  sensitive   = false
}

output "monitoring_action_group_id" {
  description = "ID of the Monitor Action Group"
  value       = module.monitoring.action_group_id
}

output "monitoring_action_group_name" {
  description = "Name of the Monitor Action Group"
  value       = module.monitoring.action_group_name
}
