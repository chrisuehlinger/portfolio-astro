locals {
  project = "portfolio-astro"

  apex_domain  = var.domain_name
  www_domain   = "www.${var.domain_name}"
  media_domain = "media.${var.domain_name}"
  cdn_domain   = "cdn.${var.domain_name}"
  old_domain   = "old.${var.domain_name}"
  cms_domain   = "cms.${var.domain_name}"

  site_bucket_name         = "chrisuehlinger-portfolio-site"
  media_bucket_name        = "chrisuehlinger-portfolio-media"
  old_bucket_name          = "chrisuehlinger-portfolio-old"
  www_redirect_bucket_name = "chrisuehlinger-portfolio-www-redirect"

  existing_cdn_bucket_name     = "cdn.chrisuehlinger.com"
  existing_cdn_website_domain  = "cdn.chrisuehlinger.com.s3-website-us-east-1.amazonaws.com"
  cloudfront_zone_id           = "Z2FDTNDATAQYW2"
  cache_policy_caching_enabled = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}
