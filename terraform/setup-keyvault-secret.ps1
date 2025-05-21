param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretValue
)

# Check if the secret exists
$secretExists = $null
try {
    $secretExists = az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "id" -o tsv
    Write-Host "Secret '$SecretName' already exists in Key Vault '$KeyVaultName'"
} catch {
    Write-Host "Secret '$SecretName' does not exist in Key Vault '$KeyVaultName'. Creating it..."
    
    # Create the secret
    az keyvault secret set --vault-name $KeyVaultName --name $SecretName --value $SecretValue
    Write-Host "Secret '$SecretName' created successfully"
}

# Output the secret URL (useful for applications that need to reference it)
$secretUrl = az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "id" -o tsv
Write-Host "Secret URL: $secretUrl" 