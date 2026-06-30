variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket used for OpenTofu remote state."
  type        = string
  default     = "chrisuehlinger-portfolio-terraform"
}
