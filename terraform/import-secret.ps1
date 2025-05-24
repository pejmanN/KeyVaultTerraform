param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretName
)

# Check if the secret exists
try {
    $secretId = az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "id" -o tsv
    Write-Host "Secret '$SecretName' found in Key Vault '$KeyVaultName'"
    Write-Host "Secret ID: $secretId"
} catch {
    Write-Host "Error: Secret '$SecretName' not found in Key Vault '$KeyVaultName'" -ForegroundColor Red
    exit 1
}

# Import the secret into Terraform state
Write-Host "Importing secret into Terraform state..."
terraform import "module.infrastructure.module.keyvault.azurerm_key_vault_secret.user_secret" $secretId

Write-Host "Secret imported successfully!" -ForegroundColor Green
Write-Host "You can now manage this secret with Terraform."
Write-Host ""
Write-Host "Note: You need to update the keyvault module to use the azurerm_key_vault_secret resource instead of null_resource."
Write-Host "Example:"
Write-Host '```'
Write-Host 'resource "azurerm_key_vault_secret" "user_secret" {'
Write-Host '  name         = "UserSetting--MySecret"'
Write-Host '  value        = "Secret From Azure KeyVault"'
Write-Host '  key_vault_id = azurerm_key_vault.keyvault.id'
Write-Host '}'
Write-Host '```' 