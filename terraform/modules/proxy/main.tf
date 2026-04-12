# Region is derived from the calling root's provider — no variable needed
data "aws_region" "current" {}

# Instance profile created once in terraform/global/ and looked up by name
data "aws_iam_instance_profile" "ec2_ssm" {
  name = "ec2-ssm-profile"
}

locals {
  aws_region = data.aws_region.current.name
  common_tags = {
    Project   = "QuickProxy"
    ManagedBy = "terraform"
  }
}
