variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used as a prefix for resource names"
  type        = string
  default     = "shipping-iac-demo"
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket used to store Terraform remote state"
  type        = string
}


variable "scp_target_id" {
  description = <<-EOT
    OU ID (ou-xxxx-xxxxxxxx) or AWS account ID to attach the deny-wildcard SCP to.
    Leave empty to create the SCP definition without attaching it.
  EOT
  type        = string
  default     = ""
}
