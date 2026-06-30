resource "aws_route53_zone" "primary" {
  name    = var.domain_name
  comment = "Portfolio DNS managed by OpenTofu."

  tags = {
    Project = "portfolio-astro"
  }

  lifecycle {
    prevent_destroy = true
  }
}
