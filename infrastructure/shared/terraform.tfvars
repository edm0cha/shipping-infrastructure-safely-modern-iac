# Replace these values before running terraform apply in shared/
github_org   = "edm0cha"
github_repo  = "shipping-infrastructure-safely-modern-iac"
state_bucket = "demo-shipping-infrastructure-safely-modern-iac"
aws_region   = "us-east-1"

# SCP attachment target — set to an OU ID (ou-xxxx-xxxxxxxx) or account ID
# to enforce the deny-wildcard policy. Leave empty to only create the policy
# definition without attaching it (safe default for reviewing first).
scp_target_id = ""

