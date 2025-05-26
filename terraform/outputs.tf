// Outputs for microservice

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.service_identity.id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.service_identity.client_id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.service_identity.principal_id
}

output "service_namespace" {
  value = var.namespace
}

output "service_name" {
  value = var.service_name
} 