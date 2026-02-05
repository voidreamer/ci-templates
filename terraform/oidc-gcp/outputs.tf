output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Workload Identity Provider name to use as workload-identity-provider in CI workflows"
}

output "service_account_email" {
  value       = google_service_account.github_actions.email
  description = "Service account email to use as service-account in CI workflows"
}

output "pool_name" {
  value       = google_iam_workload_identity_pool.github.name
  description = "Workload Identity Pool resource name"
}
