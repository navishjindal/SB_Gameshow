terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------- Locals / Lookups ----------
locals {
  frontend_bucket_name = "sanskrit-familyfeud-gameshow-frontend-4"
  ec2_tag_name         = "GameshowECSInstance"
}

# S3 bucket (frontend)
data "aws_s3_bucket" "fe" {
  bucket = local.frontend_bucket_name
}

# Find running EC2 host for backend
data "aws_instances" "gameshow_ec2" {
  filter {
    name = "tag:Name"            
    values = [local.ec2_tag_name]
  }
  filter {
    name = "instance-state-name"
    values = ["running"]
  }
}
data "aws_instance" "gameshow_ec2_primary" {
  instance_id = data.aws_instances.gameshow_ec2.ids[0]
}

# Managed CF policies
data "aws_cloudfront_cache_policy" "caching_optimized" { name = "Managed-CachingOptimized" }
data "aws_cloudfront_cache_policy" "caching_disabled"  { name = "Managed-CachingDisabled" }
data "aws_cloudfront_origin_request_policy" "all_viewer" { name = "Managed-AllViewer" }

# OAC so CF can read private S3
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "gameshow-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------- CloudFront ----------
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  # Origin 1: S3 (frontend)
  origin {
    origin_id                = "s3-frontend"
    domain_name              = data.aws_s3_bucket.fe.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  # Origin 2: EC2 backend (HTTP only; port 5004)
  origin {
    origin_id   = "ec2-backend"
    domain_name = data.aws_instance.gameshow_ec2_primary.public_dns
    custom_origin_config {
      http_port              = 5004
      https_port             = 443
      origin_protocol_policy = "http-only"    
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default: static site
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["HEAD", "GET"]
    cached_methods         = ["HEAD", "GET"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # REST API via EC2 (no cache)
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "ec2-backend"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods           = ["HEAD","GET","OPTIONS"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # Socket.IO via EC2 (preserve upgrade; no cache)
  ordered_cache_behavior {
    path_pattern             = "/socket.io/*"
    target_origin_id         = "ec2-backend"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["HEAD","DELETE","POST","GET","OPTIONS","PUT","PATCH"]
    cached_methods           = ["HEAD","GET","OPTIONS"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions { 
    geo_restriction { 
      restriction_type = "none" 
    } 
  }

  viewer_certificate {
    cloudfront_default_certificate = true 
  }

  tags = {
    Name        = "GameshowCloudFront"
    Environment = "dev"
  }
}

# Lock S3 to this distribution (OAC)
resource "aws_s3_bucket_policy" "allow_cf" {
  bucket = data.aws_s3_bucket.fe.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontRead",
      Effect    = "Allow",
      Principal = { Service = "cloudfront.amazonaws.com" },
      Action    = "s3:GetObject",
      Resource  = "arn:aws:s3:::${local.frontend_bucket_name}/*",
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn } }
    }]
  })
}

output "cloudfront_domain" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "App at https://<this>/ ; /api/* and /socket.io/* go to EC2:5004"
}
