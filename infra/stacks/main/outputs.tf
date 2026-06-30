output "route53_zone_id" {
  value = data.aws_route53_zone.primary.zone_id
}

output "cms_static_ip" {
  value = aws_lightsail_static_ip.cms.ip_address
}

output "site_bucket" {
  value = aws_s3_bucket.site.bucket
}

output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}

output "old_archive_bucket" {
  value = aws_s3_bucket.old.bucket
}

output "site_cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "site_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "media_cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.media.id
}

output "media_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.media.domain_name
}

output "cdn_archive_cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn_archive.id
}

output "cdn_archive_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn_archive.domain_name
}

output "old_cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.old.id
}

output "old_cloudfront_domain_name" {
  value = aws_cloudfront_distribution.old.domain_name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}

output "wordpress_media_iam_user" {
  value = aws_iam_user.wordpress_media.name
}

output "acm_certificate_status_note" {
  value = var.enable_custom_domains ? "Custom domains enabled; ACM validation was required for this apply." : "Custom domains disabled; rerun with enable_custom_domains=true after Route53 delegation propagates."
}
