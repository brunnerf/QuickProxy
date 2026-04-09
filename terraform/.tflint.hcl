plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Variables declared here are used in later Epic 2 stories (ec2.tf, iam.tf)
rule "terraform_unused_declarations" {
  enabled = false
}
