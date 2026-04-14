# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions OIDC Provider
#
# Bootstrap this ONCE manually:
#   cd infrastructure/shared
#   terraform init
#   terraform apply
#
# After this runs, all subsequent deploys authenticate through the IAM role
# below — no static credentials needed.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# GitHub's OIDC provider for token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # GitHub's OIDC audience value
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint for token.actions.githubusercontent.com (GitHub-managed)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    ManagedBy = "terraform"
    Project   = var.project
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role — assumed by GitHub Actions via OIDC
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_actions" {
  name        = "${var.project}-github-actions"
  description = "Assumed by GitHub Actions via OIDC — no static credentials"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scoped to this specific repository — adjust to your org/repo
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
    Project   = var.project
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Policy — minimum permissions for this demo (S3 static site + state)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_policy" "github_actions" {
  name        = "${var.project}-github-actions-policy"
  description = "Scoped permissions for GitHub Actions: S3 website + Terraform state"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WebsiteManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:ListAllMyBuckets",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
