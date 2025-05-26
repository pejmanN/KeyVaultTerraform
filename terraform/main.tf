// Microservice-specific Terraform configuration

// Azure Provider Configuration
provider "azurerm" {
  features {}
}

// Configure Terraform backend (for production, use Azure Storage)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

// Get shared infrastructure outputs
data "terraform_remote_state" "infrastructure" {
  backend = "local"
  config = {
    path = "../../AzureInfra/terraform.tfstate"
  }
}

// Create managed identity for this microservice
resource "azurerm_user_assigned_identity" "service_identity" {
  name                = "id-${var.service_name}"
  resource_group_name = data.terraform_remote_state.infrastructure.outputs.resource_group_name
  location            = data.terraform_remote_state.infrastructure.outputs.location
  tags                = var.tags
}

// Set up role assignments for Key Vault access
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = data.terraform_remote_state.infrastructure.outputs.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.service_identity.principal_id
}

resource "azurerm_role_assignment" "keyvault_secrets_officer" {
  scope                = data.terraform_remote_state.infrastructure.outputs.keyvault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.service_identity.principal_id
}

// Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.terraform_remote_state.infrastructure.outputs.aks_host
  client_certificate     = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_client_certificate)
  client_key             = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_cluster_ca_certificate)
}

// Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infrastructure.outputs.aks_host
    client_certificate     = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_client_certificate)
    client_key             = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.aks_cluster_ca_certificate)
  }
}

// Deploy microservice using Helm
resource "helm_release" "microservice" {
  count      = var.deploy_service ? 1 : 0
  name       = var.service_name
  chart      = "${path.module}/../helm"
  namespace  = var.namespace
  create_namespace = true
  
  // Set values from Terraform variables and remote state
  set {
    name  = "image.repository"
    value = "${data.terraform_remote_state.infrastructure.outputs.acr_login_server}/${var.service_name}"
  }
  
  set {
    name  = "image.tag"
    value = var.image_tag
  }
  
  set {
    name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
    value = azurerm_user_assigned_identity.service_identity.client_id
  }
  
  set {
    name  = "env.KEYVAULT_URL"
    value = data.terraform_remote_state.infrastructure.outputs.keyvault_url
  }
  
  set {
    name  = "namespace"
    value = var.namespace
  }
  
  set {
    name  = "serviceAccountName"
    value = var.service_name
  }
  
  depends_on = [
    azurerm_role_assignment.keyvault_secrets_user,
    azurerm_role_assignment.keyvault_secrets_officer
  ]
}

// Create federated credential (after Helm creates the service account)
resource "azurerm_federated_identity_credential" "service_credential" {
  count               = var.deploy_service ? 1 : 0
  name                = "fedcred-${var.service_name}"
  resource_group_name = data.terraform_remote_state.infrastructure.outputs.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.terraform_remote_state.infrastructure.outputs.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.service_identity.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_name}"
  
  depends_on = [helm_release.microservice]
} 