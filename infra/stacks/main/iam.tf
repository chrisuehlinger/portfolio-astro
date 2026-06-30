resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Project = local.project
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "portfolio-astro-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project = local.project
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid = "DeploySiteBucket"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    sid       = "InvalidateSiteDistribution"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name   = "portfolio-astro-github-actions-deploy"
  policy = data.aws_iam_policy_document.github_actions_deploy.json

  tags = {
    Project = local.project
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

resource "aws_iam_user" "wordpress_media" {
  name = "portfolio-wordpress-media-uploader"

  tags = {
    Project = local.project
    Role    = "wordpress-media-upload"
  }
}

data "aws_iam_policy_document" "wordpress_media" {
  statement {
    sid = "ListMediaBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.media.arn]
  }

  statement {
    sid = "ManageMediaObjects"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.media.arn}/*"]
  }
}

resource "aws_iam_policy" "wordpress_media" {
  name   = "portfolio-wordpress-media-upload"
  policy = data.aws_iam_policy_document.wordpress_media.json

  tags = {
    Project = local.project
  }
}

resource "aws_iam_user_policy_attachment" "wordpress_media" {
  user       = aws_iam_user.wordpress_media.name
  policy_arn = aws_iam_policy.wordpress_media.arn
}
