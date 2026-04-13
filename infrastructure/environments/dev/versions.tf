terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "REPLACE_WITH_YOUR_STATE_BUCKET"
    key            = "dev/website/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE_WITH_YOUR_LOCK_TABLE"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "shipping-iac-demo"
      Environment = "dev"
    }
  }
}
