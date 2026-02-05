output "client_id" {
  value       = azuread_application.github_actions.client_id
  description = "Azure client/app ID to use as azure-client-id in CI workflows"
}

output "tenant_id" {
  value       = data.azuread_client_config.current.tenant_id
  description = "Azure tenant ID to use as azure-tenant-id in CI workflows"
}

output "subscription_id" {
  value       = data.azurerm_subscription.current.subscription_id
  description = "Azure subscription ID to use as azure-subscription-id in CI workflows"
}
