// Infrastructure Module

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "location" {
  description = "Azure region for resources"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
}

variable "keyvault_name" {
  description = "Name of the Azure Key Vault"
}

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service cluster"
}

variable "managed_identity_name" {
  description = "Name of the Azure Managed Identity"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
}

// Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

// Import ACR Module
module "acr" {
  source              = "../acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  acr_name            = var.acr_name
}

// Import Key Vault Module
module "keyvault" {
  source              = "../keyvault"
  resource_group_name = var.resource_group_name
  location            = var.location
  keyvault_name       = var.keyvault_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
}

// Import Managed Identity Module
module "identity" {
  source               = "../identity"
  resource_group_name  = var.resource_group_name
  location             = var.location
  managed_identity_name = var.managed_identity_name
  keyvault_id          = module.keyvault.keyvault_id
}

// Import AKS Module
module "aks" {
  source                = "../aks"
  resource_group_name   = var.resource_group_name
  location              = var.location
  aks_name              = var.aks_name
  acr_id                = module.acr.acr_id
  managed_identity_id   = module.identity.managed_identity_id
  managed_identity_client_id = module.identity.managed_identity_client_id
  kubernetes_namespace  = var.kubernetes_namespace
  keyvault_url          = module.keyvault.keyvault_url
}

// Outputs
output "acr_id" {
  value = module.acr.acr_id
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "keyvault_id" {
  value = module.keyvault.keyvault_id
}

output "keyvault_url" {
  value = module.keyvault.keyvault_url
}

output "managed_identity_id" {
  value = module.identity.managed_identity_id
}

output "managed_identity_client_id" {
  value = module.identity.managed_identity_client_id
}

output "managed_identity_principal_id" {
  value = module.identity.managed_identity_principal_id
}

output "aks_host" {
  value = module.aks.host
}

output "aks_kube_config" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "aks_client_certificate" {
  value     = module.aks.client_certificate
  sensitive = true
}

output "aks_client_key" {
  value     = module.aks.client_key
  sensitive = true
}

output "aks_cluster_ca_certificate" {
  value     = module.aks.cluster_ca_certificate
  sensitive = true
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
} 