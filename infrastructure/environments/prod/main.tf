module "website" {
  # Pinned to a specific ref — treat modules like internal APIs (slide: "Modules as Contracts")
  source = "../../modules/s3-static-site"

  bucket_name = var.bucket_name

  tags = {
    Environment = "prod"
    Team        = "sre"
  }
}
