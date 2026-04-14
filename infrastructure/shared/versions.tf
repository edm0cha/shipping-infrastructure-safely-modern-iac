terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap note: this backend must be created manually before first apply.
  # Replace the placeholder values below, then run:
  #   terraform init
  #   terraform apply
  backend "s3" {
    bucket         = "demo-shipping-infrastructure-safely-modern-iac"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "shipping-iac-demo"
    }
  }
}
