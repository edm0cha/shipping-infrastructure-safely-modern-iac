variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Force to Destroy S3 Bucket"
  type        = bool
  default     = false
}
