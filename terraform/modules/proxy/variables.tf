variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the SOCKS proxy instance"
  default     = "t3.micro"
}

variable "additional_public_keys" {
  type        = list(string)
  description = "Public SSH keys for each machine that needs proxy access; each machine must have its own key"
}
