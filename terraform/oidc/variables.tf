variable "github_repos" {
  type        = list(string)
  description = "GitHub repos allowed to assume the role (e.g. ['voidreamer/my-app'])"
}

variable "role_name" {
  type        = string
  default     = "github-actions-deploy"
  description = "Name for the IAM role"
}

variable "role_path" {
  type        = string
  default     = "/"
  description = "IAM role path"
}

variable "aws_region" {
  type        = string
  default     = "ca-central-1"
  description = "AWS region for resource ARNs in the policy"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Create the GitHub OIDC provider (set false if it already exists in your account)"
}

variable "attach_cicd_policy" {
  type        = bool
  default     = true
  description = "Attach the built-in CI/CD policy (Lambda, S3, CloudFront, Terraform state)"
}

variable "managed_policy_arns" {
  type        = list(string)
  default     = []
  description = "Additional managed policy ARNs to attach to the role"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources"
}
