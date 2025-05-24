// Main Terraform configuration file

// Azure Provider Configuration
provider "azurerm" {
  features {}
}

// Define Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "orderRG"
}

variable "location" {
  description = "Azure region for resources"
  default     = "westus"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  default     = "ordercontainerregistry"
}

variable "keyvault_name" {
  description = "Name of the Azure Key Vault"
  default     = "myOrderkeyvault"
}

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service cluster"
  default     = "orderazurekuber"
}

variable "managed_identity_name" {
  description = "Name of the Azure Managed Identity"
  default     = "AzureKeyVaultServiceManageIdentity"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
  default     = "keyvaultapp"
}

variable "image_exists" {
  description = "Whether the container image exists in ACR"
  type        = bool
  default     = false
}

// Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

// Infrastructure Module (ACR, Key Vault, AKS, Managed Identity)
module "infrastructure" {
  source              = "./modules/infrastructure"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  acr_name            = var.acr_name
  keyvault_name       = var.keyvault_name
  aks_name            = var.aks_name
  managed_identity_name = var.managed_identity_name
  kubernetes_namespace  = var.kubernetes_namespace
  depends_on          = [azurerm_resource_group.rg]
}

// Application Module (Kubernetes resources)
module "application" {
  source              = "./modules/application"
  count               = var.image_exists ? 1 : 0
  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_namespace = var.kubernetes_namespace
  acr_login_server    = module.infrastructure.acr_login_server
  keyvault_url        = module.infrastructure.keyvault_url
  managed_identity_id = module.infrastructure.managed_identity_id
  managed_identity_client_id = module.infrastructure.managed_identity_client_id
  aks_oidc_issuer_url = module.infrastructure.aks_oidc_issuer_url
  depends_on          = [module.infrastructure]
}

// Configure Kubernetes Provider
provider "kubernetes" {
  host                   = module.infrastructure.aks_host
  client_certificate     = base64decode(module.infrastructure.aks_client_certificate)
  client_key             = base64decode(module.infrastructure.aks_client_key)
  cluster_ca_certificate = base64decode(module.infrastructure.aks_cluster_ca_certificate)
}

// Output Values
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = module.infrastructure.acr_login_server
}

output "keyvault_url" {
  value = module.infrastructure.keyvault_url
}

output "aks_host" {
  value = module.infrastructure.aks_host
  sensitive = true
}

output "managed_identity_client_id" {
  value = module.infrastructure.managed_identity_client_id
}

output "aks_kube_config" {
  value     = module.infrastructure.aks_kube_config
  sensitive = true
}

output "aks_oidc_issuer_url" {
  value = module.infrastructure.aks_oidc_issuer_url
} 