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

2. **Initialize Terraform**

   ```powershell
   cd terraform
   terraform init
   ```

3. **Review the Terraform Plan**

   ```powershell
   terraform plan
   ```

4. **Apply the Terraform Configuration**

   ```powershell
   terraform apply
   ```

   When prompted, type `yes` to confirm.

## Build and Push Docker Image

After the infrastructure is deployed:

1. **Build the Docker image**

   ```powershell
   docker build -t keyvaultapp:1.0.1 .
   ```

2. **Login to Azure Container Registry**

   ```powershell
   $acrLoginServer = terraform output -raw acr_login_server
   az acr login --name $(echo $acrLoginServer | cut -d'.' -f1)
   ```

3. **Tag and push the image**

   ```powershell
   docker tag keyvaultapp:1.0.1 "$acrLoginServer/keyvaultterraformapp:1.0.1"
   docker push "$acrLoginServer/keyvaultterraformapp:1.0.1"
   ```

## Connect to AKS Cluster

```powershell
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name orderazurekuber
```

## Verify Deployment

```powershell
kubectl get pods -n keyvaultapp
kubectl get services -n keyvaultapp
```

## Testing the Application

To test if the application can access the secret from Azure Key Vault:

1. Get the external IP of the service:

   ```powershell
   kubectl get services -n keyvaultapp
   ```

2. Open your browser and navigate to:

   ```
   http://<EXTERNAL-IP>/KeyVault
   ```

   You should see the secret value retrieved from Azure Key Vault.

## Clean Up

To destroy all resources created by Terraform:

```powershell
terraform destroy
```

When prompted, type `yes` to confirm.

## Customization

You can customize the deployment by modifying the variables in `main.tf` or by passing variable values during the `terraform apply` command:

```powershell
terraform apply -var="resource_group_name=myCustomRG" -var="location=eastus"
``` 