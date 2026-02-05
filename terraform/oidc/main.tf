terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# GitHub OIDC Identity Provider
# Only create if it doesn't already exist in the account
data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = var.role_name
  path = var.role_path

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.github_repos : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

# Inline policy for common CI/CD operations
resource "aws_iam_role_policy" "cicd" {
  count = var.attach_cicd_policy ? 1 : 0

  name = "${var.role_name}-cicd"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Lambda"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:ListVersionsByFunction",
          "lambda:UpdateAlias",
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:*"
      },
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*",
        ]
      },
      {
        Sid    = "CloudFront"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "*"
      },
    ]
  })
}

data "aws_caller_identity" "current" {}
