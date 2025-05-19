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

// Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

// Import modules
module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  acr_name            = var.acr_name
  depends_on          = [azurerm_resource_group.rg]
}

module "keyvault" {
  source              = "./modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  keyvault_name       = var.keyvault_name
  depends_on          = [azurerm_resource_group.rg]
}

module "identity" {
  source               = "./modules/identity"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = var.location
  managed_identity_name = var.managed_identity_name
  keyvault_id          = module.keyvault.keyvault_id
  depends_on           = [module.keyvault]
}

module "aks" {
  source                = "./modules/aks"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  aks_name              = var.aks_name
  acr_id                = module.acr.acr_id
  managed_identity_id   = module.identity.managed_identity_id
  managed_identity_client_id = module.identity.managed_identity_client_id
  kubernetes_namespace  = var.kubernetes_namespace
  keyvault_url          = module.keyvault.keyvault_url
}

// Configure Kubernetes Provider
provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

// Output Values
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = module.acr.acr_login_server
}

output "keyvault_url" {
  value = module.keyvault.keyvault_url
}

output "aks_host" {
  value = module.aks.host
  sensitive = true
}

output "managed_identity_client_id" {
  value = module.identity.managed_identity_client_id
}

output "aks_kube_config" {
  value     = module.aks.kube_config_raw
  sensitive = true
} 