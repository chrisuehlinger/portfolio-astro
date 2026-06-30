variable "aws_region" {
  description = "AWS region for regional resources."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root portfolio domain."
  type        = string
  default     = "chrisuehlinger.com"
}

variable "enable_custom_domains" {
  description = "Attach custom aliases/certificates and create Route53 alias records. Enable only after Route53 delegation and ACM validation."
  type        = bool
  default     = false
}

variable "github_owner" {
  description = "GitHub owner for OIDC trust."
  type        = string
  default     = "chrisuehlinger"
}

variable "github_repo" {
  description = "GitHub repo for OIDC trust."
  type        = string
  default     = "portfolio-astro"
}

variable "lightsail_availability_zone" {
  description = "Availability zone for the WordPress Lightsail instance."
  type        = string
  default     = "us-east-1a"
}

variable "lightsail_blueprint_id" {
  description = "Lightsail WordPress blueprint."
  type        = string
  default     = "wordpress"
}

variable "lightsail_bundle_id" {
  description = "Lightsail bundle for WordPress."
  type        = string
  default     = "small_3_0"
}

variable "media_cors_allowed_origins" {
  description = "Origins allowed to read media with CORS."
  type        = list(string)
  default = [
    "https://chrisuehlinger.com",
    "http://localhost:4321"
  ]
}
