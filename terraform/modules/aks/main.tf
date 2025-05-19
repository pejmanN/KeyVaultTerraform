// Azure Kubernetes Service Module

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "location" {
  description = "Azure region for resources"
}

variable "aks_name" {
  description = "Name of the Azure Kubernetes Service cluster"
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
}

variable "managed_identity_id" {
  description = "ID of the Azure Managed Identity"
}

variable "managed_identity_client_id" {
  description = "Client ID of the Azure Managed Identity"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
}

variable "keyvault_url" {
  description = "URL of the Azure Key Vault"
}

// Create AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_name

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    Environment = "Development"
  }
}

// Attach ACR to AKS
resource "azurerm_role_assignment" "aks_to_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = var.acr_id
  skip_service_principal_aad_check = true
}

// Create Kubernetes namespace
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
}

// Create Kubernetes Service Account
resource "kubernetes_service_account" "app_service_account" {
  metadata {
    name      = "keyvaultterraformapp-serviceaccount"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = var.managed_identity_client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }

  depends_on = [kubernetes_namespace.app_namespace]
}

// Create Federated Identity Credential
resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = "keyvaultapp-federated-credential"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = var.managed_identity_id
  subject             = "system:serviceaccount:${kubernetes_namespace.app_namespace.metadata[0].name}:${kubernetes_service_account.app_service_account.metadata[0].name}"

  depends_on = [kubernetes_service_account.app_service_account]
}

// Create Kubernetes Deployment
resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "keyvaultterraformapp-deployment"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "keyvaultterraformapp"
      }
    }

    template {
      metadata {
        labels = {
          app                           = "keyvaultterraformapp"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.app_service_account.metadata[0].name

        container {
          image = "${split("/", var.acr_id)[8]}.azurecr.io/keyvaultterraformapp:1.0.1"
          name  = "keyvaultterraformapp"

          port {
            container_port = 5002
          }

          env {
            name  = "KeyVaultSetting__Url"
            value = var.keyvault_url
          }

          resources {
            limits = {
              cpu    = "150m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "150m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_account.app_service_account]
}

// Create Kubernetes Service
resource "kubernetes_service" "app_service" {
  metadata {
    name      = "keyvaultterraformapp-service"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "keyvaultterraformapp"
    }

    port {
      port        = 80
      target_port = 5002
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.app_deployment]
}

// Outputs
output "host" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.host
}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
  sensitive = true
} 