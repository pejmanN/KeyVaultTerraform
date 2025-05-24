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

   NOTE: in this proj u can change dir to E:\TestProject\_Azure\KeyVault-Terraform\KeyVaultTerraform\terraform>
 
   This downloads required providers (e.g., azurerm for Azure). and sets up the backend. The initialization process prepares your working directory for other Terraform commands.
   


3. **Review the Terraform Plan**

   ```powershell
   terraform plan
   ```
   
   This shows what resources will be created, modified, or destroyed. It's a preview of changes that will be applied to your infrastructure.
   terraform plan can Shows the changes Terraform would apply to reach the desired state (based on your .tf code) from the current real-world state (from terraform.tfstate)
 ,for this purposeterraform plan only works with an existing state — if one exists, since `.tfstate` fille will be created on the 
  `terraform apply` step, so in the first iteration there is no .tfstate file in `terrafom plan`  step, so terrafom consider
  all resources in the `.tf` files as new resources, and in the plan show it would creae all resources.

4. **Apply the Terraform Configuration for Infra**

   ```powershell
   terraform apply
   ```
   
   This creates all the resources defined in your Terraform configuration. When prompted, type `yes` to confirm and start the deployment process.


5. **Build and Push Docker Image to ACR** 

  > its explained in seperated section to how to do that.

6. **Deploy the application**
   ```powershell
   terraform apply -var="image_exists=true"
   ```

## How Managed Identity Data Flows to Kubernetes Resources

When you run the second terraform apply -var="image_exists=true", here's exactly how the managed identity data gets passed to your Kubernetes service account:
Terraform State Preservation:

1. After your first terraform apply, Terraform stores all resource data (including managed identity details) in the state file
This state is maintained between runs, so all infrastructure data remains available
2. Data Flow in the Second Apply:
When you run  `terraform apply -var="image_exists=true"``, Terraform reads the existing state
The module.infrastructure outputs are already available, including:
managed_identity_id
managed_identity_client_id

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


**********************
### Command	Purpose
#### terraform init =>
Sets up the project (downloads provider plugins, initializes backend)

#### terraform import=>
Brings existing cloud resources into Terraform's control (tfstate)

#### terraform plan=>
Previews what will be created/changed/deleted

terraform apply	Applies the changes and updates the state file

📍 When is terraform.tfstate created?
✅ It is created during:
terraform apply (for the first time)

➤ If it doesn’t already exist, Terraform creates it after the first successful apply.
➤ It contains the real-world infrastructure state that Terraform manages.

🧠 What is stored inside .tfstate?
Real resource IDs, names, locations, and other actual values from Azure.

    Resource metadata (e.g., the id of a Key Vault, AKS, secrets, etc.).

    Output values.

    Dependencies between resources.

    So Terraform compares the .tfstate with your .tf files to decide what to do.

📁 Where is terraform.tfstate stored?
By default:
It's saved locally in your project folder (same folder as your .tf files).

The file name is:
```
terraform.tfstate

```


**********
✅ terraform refresh
🔹 Purpose:
Update the state file to reflect the actual state of your cloud environment — without making any changes to resources.

🔹 What it does:

Reads your current Terraform configuration.

Queries your cloud provider (e.g., Azure) to fetch the real state of resources.

Updates your local state file to match what actually exists.

Does NOT create, modify, or delete any resources.

🔹 Use when:

Your state file is out of sync (e.g., after manual changes in the Azure Portal).

You want to verify what's currently deployed, without changing anything.

You need to refresh output values based on the current state of resources.

✅ terraform apply
🔹 Purpose:
Create, update, or delete resources to bring your cloud environment in sync with your Terraform configuration.

🔹 What it does:

Reads your Terraform code (HCL).

Compares it against the current state file.

Generates a plan of required changes.

Asks for your confirmation.

Applies changes to the cloud.

Updates your state file accordingly.

🔹 Use when:

You want to deploy or update infrastructure.

You’ve made changes to your Terraform code and are ready to apply them.

🔸 In your case: for the initial deployment of your Azure infrastructure.

✅ terraform apply -var="image_exists=true"
🔹 Purpose:
Same as terraform apply, but overrides the value of a specific variable (image_exists).

🔹 What it does:

Performs all actions of terraform apply.

Temporarily sets the variable image_exists to true.

🔹 Use when:

You want to override a variable defined in your Terraform files.

You want to conditionally deploy specific parts of your infrastructure.

🔸 In your case: triggers the second deployment step — deploying Kubernetes resources after the Docker image has been built and pushed.
