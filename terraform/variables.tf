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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Service     = "MyService"
  }
} 