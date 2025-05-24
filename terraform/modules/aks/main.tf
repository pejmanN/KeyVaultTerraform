// Azure Kubernetes Service Module

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "location" {
  description = "Azure region for resources"
}

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service cluster"
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
}

variable "managed_identity_id" {
  description = "ID of the Azure Managed Identity"
}

variable "managed_identity_client_id" {
  description = "Client ID of the Azure Managed Identity"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
}

variable "keyvault_url" {
  description = "URL of the Azure Key Vault"
}

// Create AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_name

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    Environment = "Development"
  }
}

// Attach ACR to AKS
resource "azurerm_role_assignment" "aks_to_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}

// Outputs
output "host" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.host
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
  sensitive = true
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
} 