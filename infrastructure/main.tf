module "website" {
  source        = "./modules/s3-static-site"
  bucket_name   = var.bucket_name
  force_destroy = var.bucket_force_destroy
}
