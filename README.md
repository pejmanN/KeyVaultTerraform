# Azure KeyVault Terraform Infrastructure

This Terraform project automates the deployment of Azure infrastructure for a KeyVault-enabled application on AKS.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or newer)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (latest version)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (optional, for direct cluster management)
- Docker (for building and pushing container images)

## Project Structure

```
terraform/
├── main.tf              # Main configuration file
├── versions.tf          # Terraform and provider versions
├── modules/
│   ├── acr/            # Azure Container Registry module
│   ├── aks/            # Azure Kubernetes Service module
│   ├── keyvault/       # Azure Key Vault module
│   └── identity/       # Azure Managed Identity module
└── README.md           # This file
```

## File Descriptions

### Main Configuration Files

1. **main.tf**
   - Defines the Azure provider configuration
   - Declares variables for resource names and locations
   - Creates the resource group
   - Imports and configures all modules (ACR, AKS, Key Vault, Managed Identity)
   - Sets up dependencies between resources
   - Defines output values for important resource properties

2. **versions.tf**
   - Specifies the required Terraform version (>= 1.0.0)
   - Defines required provider versions:
     - Azure RM provider (~> 3.0)
     - Kubernetes provider (~> 2.0)

### Module Files

1. **modules/acr/main.tf**
   - Creates an Azure Container Registry with Basic SKU
   - Outputs the ACR ID and login server URL
   - Used to store Docker images for the application

2. **modules/keyvault/main.tf**
   - Creates an Azure Key Vault for storing secrets
   - Sets up access policies for the current user
   - Creates a sample secret "UserSetting--MySecret"
   - Outputs the Key Vault ID and URL

3. **modules/identity/main.tf**
   - Creates a User Assigned Managed Identity
   - Assigns "Key Vault Secrets User" role to the identity
   - Outputs the identity's ID, client ID, and principal ID
   - Enables secure access to Key Vault from AKS

4. **modules/aks/main.tf**
   - Creates an AKS cluster with workload identity enabled
   - Sets up role assignment for AKS to pull from ACR
   - Creates Kubernetes namespace, service account, and federated identity
   - Deploys the application with proper identity configuration
   - Creates a LoadBalancer service to expose the application
   - Configures the Kubernetes provider for managing resources

## Getting Started

1. **Login to Azure**

   ```powershell
   az login
   ```
   
   This authenticates your local Azure CLI with your Azure account, allowing Terraform to use your credentials.

2. **Initialize Terraform**

   ```powershell
   cd terraform
   terraform init
   ```
   
   This downloads required providers and sets up the backend. The initialization process prepares your working directory for other Terraform commands.

3. **Review the Terraform Plan**

   ```powershell
   terraform plan
   ```
   
   This shows what resources will be created, modified, or destroyed. It's a preview of changes that will be applied to your infrastructure.

4. **Apply the Terraform Configuration**

   ```powershell
   terraform apply
   ```
   
   This creates all the resources defined in your Terraform configuration. When prompted, type `yes` to confirm and start the deployment process.

## Build and Push Docker Image

After the infrastructure is deployed:

1. **Build the Docker image**

   ```powershell
   docker build -t keyvaultterraformapp:1.0.1 .
   ```
   
   This builds a Docker image of your application with the tag "keyvaultapp:1.0.1" using the Dockerfile in your project.

2. **Login to Azure Container Registry**

   ```powershell
   $azureContainerRegistryName = "ordercontainerregistry"
   $serviceGroupName = "orderRG"
   $resourceGroupLocation = "westus"
   az acr login --name $azureContainerRegistryName

   ```
   
   This retrieves the ACR login server URL from Terraform outputs and authenticates Docker with your Azure Container Registry.

3. **Tag and push the image**

   ```powershell
  
   $azureContainerRegistryAddress=$(az acr show --name $azureContainerRegistryName --query "loginServer" --output tsv)

   docker tag keyvaultterraformapp:1.0.1 "$azureContainerRegistryAddress/keyvaultterraformapp:1.0.1"
   docker push "$azureContainerRegistryAddress/keyvaultterraformapp:1.0.1"
   ```
   
   This tags your local image with the ACR repository name and pushes it to your Azure Container Registry, making it available for AKS to pull.

## Connect to AKS Cluster

```powershell
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name orderazurekuber
```

This command retrieves the AKS cluster credentials and merges them into your local kubeconfig file, allowing you to use kubectl to manage your cluster.

## Verify Deployment

```powershell
kubectl get pods -n keyvaultapp
kubectl get services -n keyvaultapp
```

These commands check if your pods are running correctly and if the service is properly exposed with an external IP.

## Testing the Application

To test if the application can access the secret from Azure Key Vault:

1. Get the external IP of the service:

   ```powershell
   kubectl get services -n keyvaultapp
   ```
   
   This retrieves the external IP address assigned to your LoadBalancer service.

2. Open your browser and navigate to:

   ```
   http://<EXTERNAL-IP>/KeyVault
   ```
   
   This accesses your application's KeyVault endpoint, which should display the secret retrieved from Azure Key Vault.

## Key Features of This Terraform Configuration

1. **Workload Identity Integration**
   - Automatically sets up the Azure Workload Identity federation
   - Dynamically configures the service account with the correct client ID
   - Eliminates the need for storing credentials in the application

2. **Modular Design**
   - Each Azure service is isolated in its own module
   - Makes the configuration easier to understand and maintain
   - Enables reuse of modules in other projects

3. **Dependency Management**
   - Resources are created in the correct order
   - Explicit dependencies prevent race conditions
   - Ensures proper integration between services

4. **Secret Management**
   - Key Vault secrets are created as part of the infrastructure
   - RBAC permissions are automatically configured
   - Secure access from AKS pods via Workload Identity

## Clean Up

To destroy all resources created by Terraform:

```powershell
terraform destroy
```

This command removes all resources created by Terraform. When prompted, type `yes` to confirm. This helps prevent unnecessary Azure charges.

## Customization

You can customize the deployment by modifying the variables in `main.tf` or by passing variable values during the `terraform apply` command:

```powershell
terraform apply -var="resource_group_name=myCustomRG" -var="location=eastus"
```

This allows you to deploy to different regions or use different resource names without modifying the Terraform files. 