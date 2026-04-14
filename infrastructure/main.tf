module "website" {
  source      = "./modules/s3-static-site"
  bucket_name = var.bucket_name
  tags = {
    Environment = var.environment
  }
}