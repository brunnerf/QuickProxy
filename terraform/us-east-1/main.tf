terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1" # Virginia
}

variable "additional_public_keys" {
  type        = list(string)
  description = "Public SSH keys for each machine that needs proxy access"
}

module "proxy" {
  source                 = "../modules/proxy"
  additional_public_keys = var.additional_public_keys
}

output "instance_id" {
  description = "EC2 instance ID — looked up dynamically by the proxy workflow; shown here for reference"
  value       = module.proxy.instance_id
}

output "public_ip" {
  description = "Current public IP of the Virginia proxy (changes on each start)"
  value       = module.proxy.public_ip
}
