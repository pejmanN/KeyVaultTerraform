param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretName,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretValue
)

# Check if the Key Vault exists
try {
    $keyVault = az keyvault show --name $KeyVaultName --query "name" -o tsv
    Write-Host "Key Vault '$KeyVaultName' found"
} catch {
    Write-Host "Error: Key Vault '$KeyVaultName' not found" -ForegroundColor Red
    exit 1
}

# Check if the secret already exists
$secretExists = $false
try {
    $existingSecret = az keyvault secret show --vault-name $KeyVaultName --name $SecretName --query "id" -o tsv
    $secretExists = $true
    Write-Host "Secret '$SecretName' already exists in Key Vault '$KeyVaultName'"
    
    $confirmation = Read-Host "Do you want to update the secret value? (y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "Operation cancelled by user"
        exit 0
    }
} catch {
    Write-Host "Secret '$SecretName' does not exist in Key Vault '$KeyVaultName', creating new secret"
}

# Set the secret
try {
    az keyvault secret set --vault-name $KeyVaultName --name $SecretName --value $SecretValue
    
    if ($secretExists) {
        Write-Host "Secret '$SecretName' updated successfully" -ForegroundColor Green
    } else {
        Write-Host "Secret '$SecretName' created successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "Error: Failed to set secret '$SecretName'" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "Note: This secret is managed outside of Terraform. If you want Terraform to manage it,"
Write-Host "you can import it using the import-secret.ps1 script:"
Write-Host "./import-secret.ps1 -KeyVaultName '$KeyVaultName' -SecretName '$SecretName'" 