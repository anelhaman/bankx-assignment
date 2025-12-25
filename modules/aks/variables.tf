variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_node_count" {
  description = "Initial number of nodes in AKS cluster"
  type        = number
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
}

variable "network_plugin" {
  description = "Network plugin for AKS"
  type        = string
}

variable "private_subnet_id" {
  description = "ID of the private subnet for AKS"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  type        = string
}

variable "application_gateway_id" {
  description = "ID of the Application Gateway for AGIC addon"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
