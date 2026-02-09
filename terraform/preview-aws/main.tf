# Preview Deployments Infrastructure (AWS)
#
# Creates a shared S3 bucket + CloudFront distribution for per-PR preview deployments.
# Each PR gets deployed to /pr-{number}/ within the bucket.
#
# Usage:
#   module "previews" {
#     source              = "github.com/voidreamer/ci-templates//terraform/preview-aws"
#     project_name        = "my-app"
#     preview_domain      = "previews.example.com"
#     acm_certificate_arn = var.acm_certificate_arn
#   }
#
# After applying:
#   1. Set GitHub secret: PREVIEW_CLOUDFRONT_ID = module.previews.cloudfront_id
#   2. Add DNS CNAME: previews.example.com -> module.previews.cloudfront_domain

variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
}

variable "preview_domain" {
  description = "Domain for preview deployments (e.g. previews.example.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 (must cover the preview domain)"
  type        = string
}

variable "expiration_days" {
  description = "Auto-delete preview objects after this many days (safety net)"
  type        = number
  default     = 30
}

# ──────────────────────────────────────
# S3 Bucket
# ──────────────────────────────────────
resource "aws_s3_bucket" "previews" {
  bucket = "${var.project_name}-previews"

  tags = {
    Name        = "${var.project_name}-previews"
    Environment = "preview"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "previews" {
  bucket = aws_s3_bucket.previews.id

  rule {
    id     = "auto-expire-stale-previews"
    status = "Enabled"

    expiration {
      days = var.expiration_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "previews" {
  bucket = aws_s3_bucket.previews.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────
# CloudFront OAC
# ──────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "previews" {
  name                              = "${var.project_name}-previews-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ──────────────────────────────────────
# S3 Bucket Policy
# ──────────────────────────────────────
resource "aws_s3_bucket_policy" "previews" {
  bucket = aws_s3_bucket.previews.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFront"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.previews.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.previews.arn
          }
        }
      }
    ]
  })
}

# ──────────────────────────────────────
# CloudFront Function (SPA rewrite)
# ──────────────────────────────────────
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.project_name}-preview-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  code    = file("${path.module}/functions/preview-spa-rewrite.js")
}

# ──────────────────────────────────────
# CloudFront Distribution
# ──────────────────────────────────────
resource "aws_cloudfront_distribution" "previews" {
  enabled             = true
  comment             = "${var.project_name} PR preview deployments"
  default_root_object = "index.html"
  aliases             = [var.preview_domain]
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.previews.bucket_regional_domain_name
    origin_id                = "previews-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.previews.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "previews-s3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  tags = {
    Name        = "${var.project_name}-previews"
    Environment = "preview"
  }
}
