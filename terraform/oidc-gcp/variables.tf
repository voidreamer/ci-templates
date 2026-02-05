variable "gcp_project_id" {
  type        = string
  description = "GCP project ID"
}

variable "github_repos" {
  type        = list(string)
  description = "GitHub repos allowed to authenticate (e.g. ['voidreamer/my-app'])"
}

variable "pool_id" {
  type        = string
  default     = "github-actions"
  description = "Workload Identity Pool ID"
}

variable "service_account_id" {
  type        = string
  default     = "github-actions-deploy"
  description = "Service account ID"
}

variable "roles" {
  type = list(string)
  default = [
    "roles/run.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/compute.urlMapAdmin",
  ]
  description = "IAM roles to grant the service account"
}
