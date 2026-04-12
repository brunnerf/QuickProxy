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

# IAM is a global service; eu-west-1 is used only because the state bucket lives there
provider "aws" {
  region = "eu-west-1"
}

locals {
  common_tags = {
    Project   = "QuickProxy"
    ManagedBy = "terraform"
  }
}
