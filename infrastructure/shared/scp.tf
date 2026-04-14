# ─────────────────────────────────────────────────────────────────────────────
# Service Control Policy — Deny non-t3.micro EC2 instances
#
# Demonstrates the "ultimate backstop" from the demo:
#   Even if a developer changes instance_type in Terraform and the IAM policy
#   allows ec2:RunInstances, this SCP blocks the launch at the org level.
#
# How it works:
#   ┌──────────────────────────────────────────────────────────────────┐
#   │  IAM policy: ec2:RunInstances allowed on *           ✅          │
#   │  SCP:        ec2:RunInstances denied when type ≠ t3.micro  ❌    │
#   │                                                                  │
#   │  Effective permission = IAM ∩ SCP → DENY                        │
#   │  The instance never launches — AccessDenied at request time.     │
#   └──────────────────────────────────────────────────────────────────┘
#
# Requirements:
#   - AWS Organizations must be enabled in your management account.
#   - Set `scp_target_id` in terraform.tfvars to an OU ID or account ID
#     to enforce the policy. Leave it empty to only create the definition.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_organizations_policy" "deny_non_t3_micro" {
  name        = "${var.project}-deny-non-t3-micro"
  description = "Blocks any EC2 instance launch where the instance type is not t3.micro."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyNonT3MicroEC2"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          StringNotEquals = {
            "ec2:InstanceType" = "t3.micro"
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

resource "aws_organizations_policy_attachment" "deny_non_t3_micro" {
  count = var.scp_target_id != "" ? 1 : 0

  policy_id = aws_organizations_policy.deny_non_t3_micro.id
  target_id = var.scp_target_id
}
