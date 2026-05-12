output "bucket_name" {
  description = "S3 bucket name (used by CI to upload content)"
  value       = module.website.bucket_name
}

output "website_url" {
  description = "Public website URL"
  value       = module.website.website_endpoint
}