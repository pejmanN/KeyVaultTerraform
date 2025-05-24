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

variable "tenant_id" {
  description = "Azure tenant ID"
}

variable "object_id" {
  description = "Object ID of the current user"
}

// Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

// Create Azure Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                        = var.keyvault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  // Grant permissions to the current user (useful for initial setup)
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id

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
  principal_id         = var.object_id
}

// Use a null_resource with local-exec to create the secret if it doesn't exist
resource "null_resource" "create_secret_if_not_exists" {
  triggers = {
    key_vault_id = azurerm_key_vault.keyvault.id
  }

  provisioner "local-exec" {
    command = <<EOT
      $secretExists = $null
      try {
        $secretExists = az keyvault secret show --vault-name ${var.keyvault_name} --name "UserSetting--MySecret" --query "id" -o tsv
        Write-Host "Secret 'UserSetting--MySecret' already exists in Key Vault '${var.keyvault_name}'"
      } catch {
        Write-Host "Secret 'UserSetting--MySecret' does not exist in Key Vault '${var.keyvault_name}'. Creating it..."
        az keyvault secret set --vault-name ${var.keyvault_name} --name "UserSetting--MySecret" --value "Secret From Azure KeyVault"
        Write-Host "Secret 'UserSetting--MySecret' created successfully"
      }
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [azurerm_role_assignment.keyvault_admin]
}

// Outputs
output "keyvault_id" {
  value = azurerm_key_vault.keyvault.id
}

output "keyvault_url" {
  value = azurerm_key_vault.keyvault.vault_uri
} 