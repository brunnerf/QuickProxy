output "iam_role_arn" {
  description = "ARN of the GitHub Actions OIDC IAM role — set as ROLE_ARN in GitHub Actions secrets"
  value       = aws_iam_role.github_oidc.arn
}

output "client_role_arn" {
  description = "ARN of the quickproxy-client-role — use as role_arn in ~/.aws/config for the quickproxy-client profile"
  value       = aws_iam_role.client.arn
}

output "base_user_arn" {
  description = "ARN of the quickproxy-base IAM user — after apply, run: aws iam create-access-key --user-name quickproxy-base"
  value       = aws_iam_user.base.arn
}

output "instance_id" {
  description = "EC2 instance ID of the SOCKS proxy — set as INSTANCE_ID in GitHub Actions secrets"
  value       = aws_instance.proxy.id
}

output "public_ip" {
  description = "Current public IP of the EC2 instance (changes on each start)"
  value       = aws_instance.proxy.public_ip
}
