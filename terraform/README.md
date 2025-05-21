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
   - Configures the Kubernetes provider using AKS outputs
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
   - Outputs AKS credentials needed for Kubernetes provider configuration

## Provider Configuration

The Terraform configuration uses two main providers:

1. **Azure Resource Manager (azurerm)** - Manages all Azure resources
2. **Kubernetes** - Manages Kubernetes resources inside the AKS cluster

The Kubernetes provider is configured in the root module (main.tf) using outputs from the AKS module:

```hcl
provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}
```

This approach avoids the "Module is incompatible with count, for_each, and depends_on" error that occurs when provider configurations are included within modules.

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
   docker build -t keyvaultapp:1.0.1 .
   ```
   
   This builds a Docker image of your application with the tag "keyvaultapp:1.0.1" using the Dockerfile in your project.

2. **Login to Azure Container Registry**

   ```powershell
   $acrLoginServer = terraform output -raw acr_login_server
   az acr login --name $(echo $acrLoginServer | cut -d'.' -f1)
   ```
   
   This retrieves the ACR login server URL from Terraform outputs and authenticates Docker with your Azure Container Registry.

3. **Tag and push the image**

   ```powershell
   docker tag keyvaultapp:1.0.1 "$acrLoginServer/keyvaultterraformapp:1.0.1"
   docker push "$acrLoginServer/keyvaultterraformapp:1.0.1"
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

## Troubleshooting

### Provider Configuration Issues

If you encounter the following error:

```
Error: Module is incompatible with count, for_each, and depends_on
```

This is typically caused by having provider configurations inside modules. The solution is to:

1. Move all provider configurations to the root module
2. Pass necessary credentials from the root module to child modules
3. Remove any `depends_on` attributes from module blocks that reference modules with their own provider configurations

### Kubernetes Resource Timing Issues

If Kubernetes resources fail to create because the AKS cluster isn't fully ready:

1. Apply the Terraform configuration in stages:
   ```powershell
   terraform apply -target=module.acr -target=module.keyvault -target=module.identity -target=azurerm_kubernetes_cluster.aks
   terraform apply
   ```

2. Or add a local-exec provisioner to wait for the cluster:
   ```hcl
   resource "null_resource" "delay" {
     depends_on = [module.aks]
     provisioner "local-exec" {
       command = "sleep 60"
     }
   }
   ```

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

## Key Vault Secret Management

Terraform can manage Key Vault secrets in two ways:

### Option 1: Using the null_resource Approach (Default)

The current implementation uses a `null_resource` with a `local-exec` provisioner to:
1. Check if the secret exists
2. Create it only if it doesn't exist

This approach avoids conflicts with existing secrets and is managed as part of the Terraform workflow. It's included in the main Terraform configuration, so you don't need to do anything special.

### Option 2: Import Existing Secret

If you prefer to use the standard `azurerm_key_vault_secret` resource and want Terraform to manage an existing secret, you need to import it into Terraform's state:

```powershell
./import-secret.ps1 -KeyVaultName "myOrderkeyvault" -SecretName "UserSetting--MySecret"
```

This script will:
1. Find the existing secret in your Key Vault
2. Import it into Terraform's state
3. Allow Terraform to manage the secret going forward

After importing, you can modify the `keyvault/main.tf` file to use the `azurerm_key_vault_secret` resource instead of the `null_resource`.

### Option 3: Separate Secret Management

You can also use the provided PowerShell script to manage the secret entirely outside of Terraform:

```powershell
./setup-keyvault-secret.ps1 -KeyVaultName "myOrderkeyvault" -SecretName "UserSetting--MySecret" -SecretValue "Secret From Azure KeyVault"
```

This gives you the most flexibility but requires running the script separately after Terraform deployment.

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




***************************************************************
## NOTE

#### Define Output
In Another Terraform Module
Let’s say you have this output in module A:
```
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}
```
Then in module B, you can do:
```
module "infra" {
  source = "./moduleA"
}

resource "azurerm_storage_account" "sa" {
  name                     = "myuniquestorage"
  resource_group_name      = module.infra.resource_group_name
  ...
}

```

In the `aks/main.tf` we have :
```
 dns_prefix = var.aks_name
```
✅ What it does:
This defines the prefix used to generate a DNS name for your AKS API server endpoint (used by kubectl or Kubernetes dashboard).

Azure will create a DNS name like:
```
https://<dns_prefix>-<hash>.<region>.azmk8s.io
https://orderazurekuber-abcd.westus.azmk8s.io
```
⚠️ What happens if you don’t set it?
❌ Terraform will throw an error. This field is required unless you use private_cluster_enabled = true (which hides the API server from public access).

Without it, AKS doesn't know what to name the public endpoint for the Kubernetes API.


🔐 1.  `identity { type = "SystemAssigned" } – AKS Cluster's Own Identity`

You are telling Azure:

> “Please generate a System-Assigned Managed Identity for this AKS cluster.”

✅ What does it do?
This creates a Managed Identity for the AKS cluster itself — think of it like a "username" that the control plane can use to interact with Azure resources on behalf of the cluster.

📦 What is "SystemAssigned"?
Azure automatically creates and manages this identity.

It is tied to the lifecycle of the AKS resource.

If you delete the AKS cluster, the identity is deleted automatically.

⚙️ What can this identity do?
This identity belongs to the control plane — not your app. It can:

Pull container images from ACR

If you give it AcrPull role on your ACR.

So AKS can download and run your containers.

Integrate with Azure Monitor & Log Analytics

If you enable monitoring, this identity sends logs/metrics to Azure Monitor.

Access other Azure resources (Key Vault, Storage, etc.)

Only if you manually assign it roles.

But this is shared across all workloads — not secure for per-app access.

Authenticate with Azure APIs on behalf of the AKS infrastructure

❌ Limitations:
Not suitable for application-level access to sensitive resources like Key Vault.

All pods/workloads would technically be "the same identity" — there's no separation of privilege.

Your application cannot directly assume this identity unless you use older, less secure methods (e.g. kubelet MSI + CSI driver).

🔄 `2. workload_identity_enabled = true – Enable Federated Workload Identity`
✅ What does it do?
This activates support for a new and secure way of granting per-pod identity access to Azure resources.

It enables:

Pods (workloads) to use a Kubernetes Service Account token,

which is federated with a User Assigned Managed Identity (UAMI),

so that each app has its own identity when calling Azure (e.g. Key Vault, Storage).

🧠 How does it work?
Once workload_identity_enabled = true is set:

You define a User Assigned Managed Identity (UAMI) in Azure.

You define a Kubernetes Service Account in your namespace.

You create a federated identity credential:

Bind the UAMI ↔ Kubernetes Service Account.

This tells Azure that this identity can trust the token from that ServiceAccount.

Your pod uses the ServiceAccount (via spec).

The Azure SDK running in your app automatically authenticates using the federated token → it becomes the UAMI.

✅ Benefits:
Each pod can have its own isolated identity.

No secrets or connection strings are needed.

Very secure (no cluster-wide access like SystemAssigned).

Easier to audit and control with RBAC.


Followng is for  Attaching ACR to AKS:
```
resource "azurerm_role_assignment" "aks_to_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}
```
as i already mentiond, When you write:
```
identity {
  type = "SystemAssigned"
}

```
You are telling Azure:

> “Please generate a System-Assigned Managed Identity for this AKS cluster.”

⚠️ But at this point, this identity has zero permissions by default.
Azure creates it, but:

It cannot pull images from ACR until you assign AcrPull.

It cannot access Key Vault, Monitor, Storage, etc., unless you give it a role.

It is not automatically powerful — it’s empty by design (security principle: least privilege).

✅ To grant permissions, you must explicitly assign a role to this identity
Example: Grant it access to ACR (Azure Container Registry), we have to define above , in above
```
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
```
`principal_id`: is the object ID of the system-assigned identity.

`role_definition_name`: is the permission (in this case, "AcrPull").

`scope`: is what the role applies to (ACR in this example).
