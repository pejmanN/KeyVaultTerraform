param(
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "1.0.1"
)

# Get the ACR login server
$acrLoginServer = terraform output -raw acr_login_server

Write-Host "Building and pushing Docker image to $acrLoginServer..."

# Build the Docker image
Write-Host "Building Docker image..."
docker build -t keyvaultapp:$ImageTag ..

# Login to ACR
Write-Host "Logging in to ACR..."
$acrName = $acrLoginServer.Split('.')[0]
az acr login --name $acrName

# Tag and push the image
Write-Host "Tagging and pushing the image..."
docker tag keyvaultapp:$ImageTag "$acrLoginServer/keyvaultterraformapp:$ImageTag"
docker push "$acrLoginServer/keyvaultterraformapp:$ImageTag"

Write-Host "Image pushed successfully."

Write-Host "Deploying application with Terraform..."
terraform apply -var="image_exists=true"

Write-Host "Application deployed successfully."
Write-Host "Waiting for external IP..."
kubectl get service keyvaultterraformapp-service -n keyvaultapp --watch 