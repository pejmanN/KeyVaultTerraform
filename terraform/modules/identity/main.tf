// Azure Managed Identity Module

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "location" {
  description = "Azure region for resources"
}

variable "managed_identity_name" {
  description = "Name of the Azure Managed Identity"
}

variable "keyvault_id" {
  description = "ID of the Azure Key Vault"
}

// Create User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "managed_identity" {
  name                = var.managed_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

// Assign Key Vault Secrets User role to the Managed Identity
resource "azurerm_role_assignment" "keyvault_role" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id
}

// Outputs
output "managed_identity_id" {
  value = azurerm_user_assigned_identity.managed_identity.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.managed_identity.client_id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.managed_identity.principal_id
} 