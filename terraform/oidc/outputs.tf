output "role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "IAM role ARN to use as aws-role-arn in CI workflows"
}

output "role_name" {
  value       = aws_iam_role.github_actions.name
  description = "IAM role name"
}

output "oidc_provider_arn" {
  value       = local.oidc_provider_arn
  description = "GitHub OIDC provider ARN"
}
