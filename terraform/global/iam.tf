# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider — allows GitHub Actions to assume AWS roles
# without long-lived credentials
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---------------------------------------------------------------------------
# GitHub Actions role — assumed by pipeline jobs via OIDC token exchange
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_oidc_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_oidc" {
  name               = "github-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume.json

  tags = merge(local.common_tags, { Name = "proxy-github-oidc-role" })
}

resource "aws_iam_role_policy_attachment" "github_ec2_full" {
  role       = aws_iam_role.github_oidc.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "github_iam_full" {
  # checkov:skip=CKV2_AWS_56: IAMFullAccess is intentional — the CI/CD role must manage its own IAM resources; acceptable for a single-owner personal project
  role       = aws_iam_role.github_oidc.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_s3_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}/*",
    ]
  }
}

resource "aws_iam_role_policy" "github_s3_state" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_oidc.name
  policy = data.aws_iam_policy_document.github_s3_state.json
}

# ---------------------------------------------------------------------------
# Client role — assumed by proxy users for SSM tunnel + SSH; no infra access
# Permissions use region wildcards so one role covers all three regions.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "client_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.base.arn]
    }
  }
}

resource "aws_iam_role" "client" {
  name               = "quickproxy-client-role"
  assume_role_policy = data.aws_iam_policy_document.client_assume.json
  tags               = merge(local.common_tags, { Name = "quickproxy-client-role" })
}

data "aws_iam_policy_document" "client_permissions" {
  # checkov:skip=CKV_AWS_356: ssm:Describe* and ec2:DescribeInstances do not support resource-level restrictions — "*" is required by AWS

  # Start SSM sessions only on instances tagged Project=QuickProxy (any region)
  statement {
    sid     = "SSMStartSessionInstance"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = ["QuickProxy"]
    }
  }

  # Allow use of the SSH session document (AWS-owned — empty account ID, no tags)
  statement {
    sid     = "SSMStartSessionDocument"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ssm:*::document/AWS-StartSSHSession",
    ]
  }

  # Manage own SSM sessions (any region)
  statement {
    sid    = "SSMManageSessions"
    effect = "Allow"
    actions = [
      "ssm:TerminateSession",
      "ssm:ResumeSession",
    ]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/*",
    ]
  }

  # Describe actions don't support resource-level restrictions
  statement {
    sid    = "SSMDescribe"
    effect = "Allow"
    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }

  # Resolve instance ID by tag across all regions
  statement {
    sid       = "EC2Describe"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "client_permissions" {
  name   = "quickproxy-client-permissions"
  role   = aws_iam_role.client.name
  policy = data.aws_iam_policy_document.client_permissions.json
}

# ---------------------------------------------------------------------------
# Base IAM user — only credential stored on client machines; its sole
# permission is sts:AssumeRole on the client role above.
#
# After first apply, create the access key manually (keeps the secret out of
# Terraform state):
#   aws iam create-access-key --user-name quickproxy-base
# ---------------------------------------------------------------------------

resource "aws_iam_user" "base" {
  # checkov:skip=CKV_AWS_273: SSO is not justified for a single-owner personal project; this user is a minimal service account
  name = "quickproxy-base"
  tags = merge(local.common_tags, { Name = "quickproxy-base" })
}

data "aws_iam_policy_document" "base_assume_client" {
  statement {
    sid       = "AssumeClientRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.client.arn]
  }
}

resource "aws_iam_user_policy" "base_assume_client" {
  # checkov:skip=CKV_AWS_40: inline policy intentional — this user only does sts:AssumeRole; attaching to a group adds no value here
  name   = "assume-quickproxy-client-role"
  user   = aws_iam_user.base.name
  policy = data.aws_iam_policy_document.base_assume_client.json
}

# ---------------------------------------------------------------------------
# EC2 instance role — assumed by EC2 instances in all regions for SSM access
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(local.common_tags, { Name = "proxy-ec2-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = merge(local.common_tags, { Name = "proxy-ec2-ssm-profile" })
}
