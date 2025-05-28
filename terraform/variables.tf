// Variables for microservice

variable "service_name" {
  description = "Name of the microservice"
  default     = "myservice"
}

variable "namespace" {
  description = "Kubernetes namespace for the microservice"
  default     = "myservice"
}

variable "image_tag" {
  description = "Tag of the container image"
  default     = "latest"
}

variable "deploy_service" {
  description = "Whether to deploy the service to Kubernetes"
  type        = bool
  default     = false
}

// Shared infrastructure remote state variables
variable "shared_resource_group_name" {
  description = "Resource group containing the shared infrastructure state storage"
  default     = "shared-infrastructure-rg"
}

variable "shared_storage_account_name" {
  description = "Storage account containing the shared infrastructure state"
  default     = "tfstate12345"
}

variable "shared_container_name" {
  description = "Container name for the shared infrastructure state"
  default     = "tfstate"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Service     = "MyService"
  }
} 