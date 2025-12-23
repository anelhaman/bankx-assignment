variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East Asia"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "bankx-rg"
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
  default     = "bankx-vnet"
}

variable "vnet_address_space" {
  description = "CIDR blocks for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "public_subnet_name" {
  description = "Name of the public subnet"
  type        = string
  default     = "public-subnet"
}

variable "public_subnet_address_space" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_name" {
  description = "Name of the private subnet"
  type        = string
  default     = "private-subnet"
}

variable "private_subnet_address_space" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "bankx-aks"
}

variable "aks_node_count" {
  description = "Initial number of nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
  default     = "bankx-appgw"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
  default     = "bankx-logs"
}

variable "log_analytics_retention_days" {
  description = "Retention days for Log Analytics"
  type        = number
  default     = 30
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "nodejs-hello"
}

variable "app_image" {
  description = "Docker image for Node.js app"
  type        = string
  default     = "node:18-alpine"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "BankX"
    ManagedBy   = "Terraform"
    CreatedDate = "2025-12-23"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

variable "network_plugin" {
  description = "Network plugin for AKS"
  type        = string
  default     = "azure"
}

variable "acr_username" {
  description = "Azure Container Registry username (for pull secrets)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "acr_password" {
  description = "Azure Container Registry password (for pull secrets)"
  type        = string
  sensitive   = true
  default     = ""
}
