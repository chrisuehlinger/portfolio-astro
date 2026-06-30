resource "aws_s3_bucket" "site" {
  bucket = local.site_bucket_name

  tags = {
    Project = local.project
    Role    = "site"
  }
}

resource "aws_s3_bucket" "media" {
  bucket = local.media_bucket_name

  tags = {
    Project = local.project
    Role    = "media"
  }
}

resource "aws_s3_bucket" "old" {
  bucket = local.old_bucket_name

  tags = {
    Project = local.project
    Role    = "old-site-archive"
  }
}

resource "aws_s3_bucket" "www_redirect" {
  bucket = local.www_redirect_bucket_name

  tags = {
    Project = local.project
    Role    = "www-redirect"
  }
}

resource "aws_s3_bucket_website_configuration" "www_redirect" {
  bucket = aws_s3_bucket.www_redirect.id

  redirect_all_requests_to {
    host_name = local.apex_domain
    protocol  = "https"
  }
}

resource "aws_s3_object" "placeholder_index" {
  bucket        = aws_s3_bucket.site.id
  key           = "index.html"
  source        = "${path.module}/../../assets/placeholder/index.html"
  etag          = filemd5("${path.module}/../../assets/placeholder/index.html")
  content_type  = "text/html; charset=utf-8"
  cache_control = "no-cache"

  lifecycle {
    ignore_changes = [
      cache_control,
      content_type,
      etag,
      source,
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "private_buckets" {
  for_each = {
    site  = aws_s3_bucket.site.id
    media = aws_s3_bucket.media.id
    old   = aws_s3_bucket.old.id
  }

  bucket = each.value

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "www_redirect" {
  bucket = aws_s3_bucket.www_redirect.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioned" {
  for_each = {
    site  = aws_s3_bucket.site.id
    media = aws_s3_bucket.media.id
    old   = aws_s3_bucket.old.id
  }

  bucket = each.value

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted" {
  for_each = {
    site         = aws_s3_bucket.site.id
    media        = aws_s3_bucket.media.id
    old          = aws_s3_bucket.old.id
    www_redirect = aws_s3_bucket.www_redirect.id
  }

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "owned" {
  for_each = {
    site         = aws_s3_bucket.site.id
    media        = aws_s3_bucket.media.id
    old          = aws_s3_bucket.old.id
    www_redirect = aws_s3_bucket.www_redirect.id
  }

  bucket = each.value

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    id     = "expire-noncurrent-after-90-days"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "old" {
  bucket = aws_s3_bucket.old.id

  rule {
    id     = "expire-noncurrent-after-90-days"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "expire-noncurrent-after-180-days"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.media_cors_allowed_origins
    expose_headers  = ["Accept-Ranges", "Content-Length", "Content-Range"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json
}

resource "aws_s3_bucket_policy" "media" {
  bucket = aws_s3_bucket.media.id
  policy = data.aws_iam_policy_document.media_bucket.json
}

resource "aws_s3_bucket_policy" "old" {
  bucket = aws_s3_bucket.old.id
  policy = data.aws_iam_policy_document.old_bucket.json
}

resource "aws_s3_bucket_policy" "existing_cdn_archive" {
  bucket = local.existing_cdn_bucket_name
  policy = data.aws_iam_policy_document.existing_cdn_bucket.json
}
