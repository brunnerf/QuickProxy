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
# EC2 instance role — assumed by the EC2 instance for SSM access
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
