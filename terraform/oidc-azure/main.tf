terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.47"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}

# App Registration for GitHub Actions
resource "azuread_application" "github_actions" {
  display_name = var.app_name
  owners       = [data.azuread_client_config.current.object_id]
}

# Service Principal
resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Federated Credentials for each repo
resource "azuread_application_federated_identity_credential" "github" {
  for_each = toset(var.github_repos)

  application_id = azuread_application.github_actions.id
  display_name   = replace(each.value, "/", "-")
  description    = "GitHub Actions OIDC for ${each.value}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value}:ref:refs/heads/main"
}

# Also allow staging branch
resource "azuread_application_federated_identity_credential" "github_staging" {
  for_each = toset(var.github_repos)

  application_id = azuread_application.github_actions.id
  display_name   = "${replace(each.value, "/", "-")}-staging"
  description    = "GitHub Actions OIDC for ${each.value} (staging)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value}:ref:refs/heads/staging"
}

# Role assignment on the subscription
resource "azurerm_role_assignment" "contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = var.role
  principal_id         = azuread_service_principal.github_actions.object_id
}
