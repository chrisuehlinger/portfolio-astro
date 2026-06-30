resource "aws_acm_certificate" "portfolio" {
  domain_name = local.apex_domain
  subject_alternative_names = [
    local.www_domain,
    local.media_domain,
    local.cdn_domain,
    local.old_domain
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = local.project
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for option in aws_acm_certificate.portfolio.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "portfolio" {
  count = var.enable_custom_domains ? 1 : 0

  certificate_arn         = aws_acm_certificate.portfolio.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
