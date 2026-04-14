output "bucket_name" {
  description = "S3 bucket name (used by CI to upload content)"
  value       = module.website.bucket_name
}

output "website_url" {
  description = "Public website URL"
  value       = module.website.website_endpoint
}

output "ec2_instance_id" {
  description = "Demo EC2 instance ID"
  value       = aws_instance.demo.id
}

output "ec2_private_ip" {
  description = "Demo EC2 private IP (no public IP — SSH access is disabled)"
  value       = aws_instance.demo.private_ip
}
