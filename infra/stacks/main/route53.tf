resource "aws_route53_record" "cms" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.cms_domain
  type    = "A"
  ttl     = 300
  records = [aws_lightsail_static_ip.cms.ip_address]
}

resource "aws_route53_record" "site_a" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.apex_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.apex_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_a" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.www_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_aaaa" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.www_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "media_a" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.media_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.media.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "media_aaaa" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.media_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.media.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_a" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.cdn_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_archive.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_aaaa" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.cdn_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.cdn_archive.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "old_a" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.old_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.old.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "old_aaaa" {
  count = var.enable_custom_domains ? 1 : 0

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.old_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.old.domain_name
    zone_id                = local.cloudfront_zone_id
    evaluate_target_health = false
  }
}
