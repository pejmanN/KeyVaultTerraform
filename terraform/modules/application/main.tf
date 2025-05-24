// Application Module for Kubernetes Resources

// Variables
variable "resource_group_name" {
  description = "Name of the resource group"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
}

variable "acr_login_server" {
  description = "Login server URL for Azure Container Registry"
}

variable "keyvault_url" {
  description = "URL of the Azure Key Vault"
}

variable "managed_identity_id" {
  description = "ID of the Azure Managed Identity"
}

variable "managed_identity_client_id" {
  description = "Client ID of the Azure Managed Identity"
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster"
}

variable "image_tag" {
  description = "Tag of the container image"
  default     = "1.0.1"
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
  issuer              = var.aks_oidc_issuer_url
  parent_id           = var.managed_identity_id
  subject             = "system:serviceaccount:${var.kubernetes_namespace}:keyvaultterraformapp-serviceaccount"

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
          image = "${var.acr_login_server}/keyvaultterraformapp:${var.image_tag}"
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