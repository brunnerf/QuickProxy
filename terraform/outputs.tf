output "iam_role_arn" {
  description = "ARN of the GitHub Actions OIDC IAM role — set as ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_oidc.arn
}

output "instance_id" {
  description = "EC2 instance ID of the SOCKS proxy — set as INSTANCE_ID in GitHub Actions secrets"
  value       = aws_instance.proxy.id
}

output "public_ip" {
  description = "Current public IP of the EC2 instance (changes on each start)"
  value       = aws_instance.proxy.public_ip
}
