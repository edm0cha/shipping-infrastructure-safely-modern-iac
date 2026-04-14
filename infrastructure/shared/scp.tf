# ─────────────────────────────────────────────────────────────────────────────
# Service Control Policy — Deny Wildcard Service Actions
#
# This replicates the incident from the demo:
#
#   "A team mate updated a Lambda's IAM role, needed two new permissions,
#    but instead used dynamodb:* on the policy to move faster.
#    Terraform applied it, but our organization had a policy that denied
#    wildcard actions. IAM accepted the policy change, but the SCP blocked
#    every request at runtime. Minutes later the API went down."
#
# How it works:
#   ┌──────────────────────────────────────────────────────────────┐
#   │  IAM policy on the Lambda role:  "Action": "dynamodb:*"  ✅  │
#   │  SCP on the account:             "Action": "dynamodb:*"  ❌  │
#   │                                                              │
#   │  Effective permission = IAM ∩ SCP → DENY                    │
#   │  IAM accepts the policy change (no validation against SCPs). │
#   │  At runtime every DynamoDB call fails with AccessDenied.     │
#   └──────────────────────────────────────────────────────────────┘
#
# Exemptions:
#   - OrganizationAccountAccessRole — cross-account admin access
#   - The GitHub Actions OIDC role — so the pipeline is never blocked
#
# Requirements:
#   - AWS Organizations must be enabled in your management account.
#   - Apply this from the management account (or a delegated admin account).
#   - Set `scp_target_id` to the OU ID (ou-xxxx-xxxxxxxx) or account ID
#     where the policy should be attached.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_organizations_policy" "deny_wildcard_actions" {
  name        = "${var.project}-deny-wildcard-actions"
  description = "Blocks service-level wildcard IAM actions (e.g. dynamodb:*, s3:*). Requires explicit, least-privilege permissions."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWildcardServiceActions"
        Effect = "Deny"

        # These are the wildcard action patterns the SCP blocks.
        # When a Lambda role is granted "dynamodb:*" and the SCP also
        # matches "dynamodb:*" with Deny — the deny wins, every call fails.
        Action = [
          "dynamodb:*",
          "s3:*",
          "lambda:*",
          "ec2:*",
          "iam:*",
        ]

        Resource = "*"

        Condition = {
          # Exemptions — these principals bypass the SCP so admin access
          # and the CI/CD pipeline are never accidentally blocked.
          ArnNotLike = {
            "aws:PrincipalArn" = [
              # Cross-account admin role created by AWS Organizations
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              # GitHub Actions OIDC role — lets Terraform run unblocked
              "arn:aws:iam::*:role/${var.project}-github-actions",
            ]
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
# Attach the SCP to a target OU or account
#
# Set `scp_target_id` in terraform.tfvars:
#   scp_target_id = "ou-ab12-xxxxxxxx"   # to attach to an OU
#   scp_target_id = "123456789012"        # to attach to a specific account
#
# Leave it empty ("") to skip the attachment and only create the policy
# definition (useful for reviewing before enforcing).
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_organizations_policy_attachment" "deny_wildcard_actions" {
  count = var.scp_target_id != "" ? 1 : 0

  policy_id = aws_organizations_policy.deny_wildcard_actions.id
  target_id = var.scp_target_id
}
