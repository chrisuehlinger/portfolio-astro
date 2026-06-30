variable "aws_region" {
  description = "AWS region for Route53 management calls."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root portfolio domain."
  type        = string
  default     = "chrisuehlinger.com"
}
