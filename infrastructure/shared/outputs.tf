output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC. Set this as AWS_ROLE_ARN in your GitHub repository variables."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "scp_id" {
  description = "ID of the deny-wildcard-actions SCP"
  value       = aws_organizations_policy.deny_wildcard_actions.id
}

output "scp_arn" {
  description = "ARN of the deny-wildcard-actions SCP"
  value       = aws_organizations_policy.deny_wildcard_actions.arn
}
