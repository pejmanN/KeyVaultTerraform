param(
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [switch]$BuildImage = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployService = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$AzureInfraPath = "../AzureInfra"
)

# Get the infrastructure outputs
Write-Host "Getting infrastructure outputs..."
$infraOutputs = $null
try {
    Push-Location $AzureInfraPath
    $infraOutputs = terraform output -json | ConvertFrom-Json
    Pop-Location
} catch {
    Write-Host "Error: Failed to get infrastructure outputs. Make sure the infrastructure is deployed." -ForegroundColor Red
    exit 1
}

$acrLoginServer = $infraOutputs.acr_login_server.value
$serviceName = "myservice"

# Build and push Docker image if requested
if ($BuildImage) {
    Write-Host "Building and pushing Docker image to $acrLoginServer..."

    # Build the Docker image
    Write-Host "Building Docker image..."
    docker build -t $serviceName:$ImageTag .

    # Login to ACR
    Write-Host "Logging in to ACR..."
    $acrName = $acrLoginServer.Split('.')[0]
    az acr login --name $acrName

    # Tag and push the image
    Write-Host "Tagging and pushing the image..."
    docker tag $serviceName:$ImageTag "$acrLoginServer/$serviceName:$ImageTag"
    docker push "$acrLoginServer/$serviceName:$ImageTag"

    Write-Host "Image pushed successfully." -ForegroundColor Green
}

# Deploy the service with Terraform
Write-Host "Deploying service with Terraform..."
Push-Location ./terraform

# Initialize Terraform
terraform init

# Apply with the appropriate variables
if ($DeployService) {
    terraform apply -var="image_tag=$ImageTag" -var="deploy_service=true" -auto-approve
} else {
    terraform apply -var="image_tag=$ImageTag" -var="deploy_service=false" -auto-approve
}

Pop-Location

# Show the deployed resources
if ($DeployService) {
    Write-Host "Service deployed successfully." -ForegroundColor Green
    Write-Host "Getting Kubernetes resources..."
    kubectl get all -n myservice
} else {
    Write-Host "Managed Identity and Azure resources created successfully." -ForegroundColor Green
    Write-Host "Service deployment was skipped as requested."
}

Write-Host "Deployment completed!" -ForegroundColor Green 