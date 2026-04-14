terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial backend — bucket, key, and region are injected by the pipeline
  # via -backend-config flags so each environment gets its own state file
  # without duplicating this configuration.
  #
  # Example (CI passes these per environment):
  #   -backend-config="bucket=<state-bucket>"
  #   -backend-config="key=<env>/website/terraform.tfstate"
  #   -backend-config="region=us-east-1"
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "shipping-iac-demo"
      Environment = var.environment
    }
  }
}
