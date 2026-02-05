variable "github_repos" {
  type        = list(string)
  description = "GitHub repos allowed to authenticate (e.g. ['voidreamer/my-app'])"
}

variable "app_name" {
  type        = string
  default     = "github-actions-deploy"
  description = "Azure AD app registration display name"
}

variable "role" {
  type        = string
  default     = "Contributor"
  description = "Azure role to assign (Contributor allows most CI/CD operations)"
}
