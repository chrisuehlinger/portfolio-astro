terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "chrisuehlinger-portfolio-terraform"
    key          = "portfolio-astro/main/tofu.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
