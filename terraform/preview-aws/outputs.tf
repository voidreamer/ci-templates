output "cloudfront_id" {
  value       = aws_cloudfront_distribution.previews.id
  description = "Set as PREVIEW_CLOUDFRONT_ID secret in GitHub"
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.previews.domain_name
  description = "Create CNAME: preview_domain -> this value"
}

output "bucket_name" {
  value = aws_s3_bucket.previews.id
}
