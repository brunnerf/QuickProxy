output "instance_id" {
  description = "EC2 instance ID of the SOCKS proxy"
  value       = aws_instance.proxy.id
}

output "public_ip" {
  description = "Current public IP of the EC2 instance (changes on each start)"
  value       = aws_instance.proxy.public_ip
}
