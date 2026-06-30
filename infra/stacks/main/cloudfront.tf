resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "portfolio-site-oac"
  description                       = "OAC for portfolio site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "media" {
  name                              = "portfolio-media-oac"
  description                       = "OAC for portfolio media bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "old" {
  name                              = "portfolio-old-oac"
  description                       = "OAC for old portfolio archive bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "site" {
  name = "portfolio-site-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "media" {
  name = "portfolio-media-cors"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = var.media_cors_allowed_origins
    }

    access_control_expose_headers {
      items = ["Accept-Ranges", "Content-Length", "Content-Range"]
    }

    access_control_max_age_sec = 3600
    origin_override            = true
  }
}

resource "aws_cloudfront_response_headers_policy" "cdn_archive" {
  name = "portfolio-cdn-archive-cors"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["Accept-Ranges", "Content-Length", "Content-Range"]
    }

    access_control_max_age_sec = 3600
    origin_override            = true
  }
}

resource "aws_cloudfront_function" "directory_index" {
  name    = "portfolio-directory-index"
  runtime = "cloudfront-js-1.0"
  comment = "Map clean static URLs to index.html objects."
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.includes('.')) {
        request.uri = uri + '/index.html';
      }

      return request;
    }
  JS
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Portfolio Astro site"
  default_root_object = "index.html"
  aliases             = var.enable_custom_domains ? [local.apex_domain] : []

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
    origin_id                = "site-s3"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = local.cache_policy_caching_enabled
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id
    target_origin_id           = "site-s3"
    viewer_protocol_policy     = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.directory_index.arn
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_custom_domains ? null : true
    acm_certificate_arn            = var.enable_custom_domains ? aws_acm_certificate_validation.portfolio[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }
}

resource "aws_cloudfront_distribution" "www_redirect" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Redirect www.chrisuehlinger.com to apex"
  aliases         = var.enable_custom_domains ? [local.www_domain] : []

  origin {
    domain_name = aws_s3_bucket_website_configuration.www_redirect.website_endpoint
    origin_id   = "www-redirect-s3-website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.cache_policy_caching_enabled
    compress               = true
    target_origin_id       = "www-redirect-s3-website"
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_custom_domains ? null : true
    acm_certificate_arn            = var.enable_custom_domains ? aws_acm_certificate_validation.portfolio[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }
}

resource "aws_cloudfront_distribution" "media" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Portfolio WordPress media"
  aliases         = var.enable_custom_domains ? [local.media_domain] : []

  origin {
    domain_name              = aws_s3_bucket.media.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.media.id
    origin_id                = "media-s3"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = local.cache_policy_caching_enabled
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.media.id
    target_origin_id           = "media-s3"
    viewer_protocol_policy     = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_custom_domains ? null : true
    acm_certificate_arn            = var.enable_custom_domains ? aws_acm_certificate_validation.portfolio[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }
}

resource "aws_cloudfront_distribution" "cdn_archive" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Archive distribution for existing cdn.chrisuehlinger.com S3 bucket"
  aliases         = var.enable_custom_domains ? [local.cdn_domain] : []

  origin {
    domain_name = local.existing_cdn_website_domain
    origin_id   = "existing-cdn-s3-website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = local.cache_policy_caching_enabled
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn_archive.id
    target_origin_id           = "existing-cdn-s3-website"
    viewer_protocol_policy     = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_custom_domains ? null : true
    acm_certificate_arn            = var.enable_custom_domains ? aws_acm_certificate_validation.portfolio[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }
}

resource "aws_cloudfront_distribution" "old" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Old portfolio archive"
  default_root_object = "index.html"
  aliases             = var.enable_custom_domains ? [local.old_domain] : []

  origin {
    domain_name              = aws_s3_bucket.old.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.old.id
    origin_id                = "old-s3"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = local.cache_policy_caching_enabled
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id
    target_origin_id           = "old-s3"
    viewer_protocol_policy     = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.directory_index.arn
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 60
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.enable_custom_domains ? null : true
    acm_certificate_arn            = var.enable_custom_domains ? aws_acm_certificate_validation.portfolio[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domains ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domains ? "TLSv1.2_2021" : null
  }
}
