param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretName,
    
    [Parameter(Mandatory=$false)]
    [string]$SecretVersion
)

# Get the Key Vault ID
$keyVaultId = az keyvault show --name $KeyVaultName --query "id" -o tsv

if (-not $SecretVersion) {
    # Get the latest version of the secret
    $secretId = az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "id" -o tsv
} else {
    # Use the specified version
    $secretId = "https://$KeyVaultName.vault.azure.net/secrets/$SecretName/$SecretVersion"
}

Write-Host "Importing secret $secretId into Terraform state..."

# Import the secret into Terraform state
terraform import "module.keyvault.azurerm_key_vault_secret.user_secret" $secretId

Write-Host "Secret imported successfully. You can now use terraform apply to manage it." 