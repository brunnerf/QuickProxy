variable "aws_region" {
  type        = string
  description = "AWS region where all resources will be provisioned"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the SOCKS proxy instance"
  default     = "t3.micro"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g. \"10.0.0.0/16\")"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in \"owner/repo\" format — used to scope the OIDC trust policy (e.g. \"brunnerf/QuickProxy\")"
}

variable "additional_public_keys" {
  type        = list(string)
  description = "Public SSH keys for each machine that needs proxy access; each machine must have its own key (never share private keys across machines)"
}
