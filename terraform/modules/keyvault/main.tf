// Azure Key Vault Module

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "location" {
  description = "Azure region for resources"
}

variable "keyvault_name" {
  description = "Name of the Azure Key Vault"
}

// Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

// Create Azure Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                        = var.keyvault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  // Grant permissions to the current user (useful for initial setup)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete",
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete",
    ]
  }
}

// Assign Key Vault Administrator role to the current user
resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

// Create a secret for the application
resource "azurerm_key_vault_secret" "user_secret" {
  name         = "UserSetting--MySecret"
  value        = "Secret From Azure KeyVault"
  key_vault_id = azurerm_key_vault.keyvault.id
  
  depends_on = [azurerm_role_assignment.keyvault_admin]
}

// Outputs
output "keyvault_id" {
  value = azurerm_key_vault.keyvault.id
}

output "keyvault_url" {
  value = azurerm_key_vault.keyvault.vault_uri
} 