#!/usr/bin/env bash
# bootstrap.sh — one-time setup for a new AWS account
#
# Run this locally with valid AWS credentials (aws configure) before the
# first terraform apply. It creates the S3 state bucket, GitHub OIDC
# provider, and IAM role so the GitHub Actions pipeline can authenticate
# via OIDC without long-lived credentials.
#
# Usage:
#   bash scripts/bootstrap.sh <aws-region> <github-repo>
#
# Example:
#   bash scripts/bootstrap.sh eu-west-1 brunnerf/QuickProxy
#
# Idempotent — safe to run multiple times on the same account.

set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------

REGION="${1:?Usage: bootstrap.sh <aws-region> <github-repo>}"
GITHUB_REPO="${2:?Usage: bootstrap.sh <aws-region> <github-repo>}"

# ---------------------------------------------------------------------------
# Derive values
# ---------------------------------------------------------------------------

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="terraform-state-${ACCOUNT_ID}"
ROLE_NAME="github-oidc-role"
GITHUB_OIDC_URL="https://token.actions.githubusercontent.com"
GITHUB_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

echo "==> Account:     ${ACCOUNT_ID}"
echo "==> Region:      ${REGION}"
echo "==> Bucket:      ${BUCKET}"
echo "==> GitHub repo: ${GITHUB_REPO}"
echo ""

# ---------------------------------------------------------------------------
# S3 state bucket
# ---------------------------------------------------------------------------

echo "==> Creating S3 state bucket..."

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "    Bucket already exists, skipping creation."
else
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  echo "    Bucket created."
fi

echo "==> Enabling versioning..."
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Blocking public access..."
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ---------------------------------------------------------------------------
# GitHub OIDC provider
# ---------------------------------------------------------------------------

echo "==> Creating GitHub OIDC provider..."

PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${PROVIDER_ARN}" 2>/dev/null; then
  echo "    OIDC provider already exists, skipping."
else
  aws iam create-open-id-connect-provider \
    --url "${GITHUB_OIDC_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "${GITHUB_THUMBPRINT}"
  echo "    OIDC provider created."
fi

# ---------------------------------------------------------------------------
# IAM role trust policy
# ---------------------------------------------------------------------------

echo "==> Creating IAM role..."

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "${ROLE_NAME}" 2>/dev/null; then
  echo "    Role already exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "${TRUST_POLICY}"
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}"
  echo "    Role created."
fi

# ---------------------------------------------------------------------------
# IAM role policies
# ---------------------------------------------------------------------------

echo "==> Attaching managed policies..."

for POLICY_ARN in \
  "arn:aws:iam::aws:policy/AmazonEC2FullAccess" \
  "arn:aws:iam::aws:policy/IAMFullAccess"; do
  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "    ${POLICY_ARN} already attached."
done

echo "==> Attaching inline S3 state policy..."

S3_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET}",
        "arn:aws:s3:::${BUCKET}/*"
      ]
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "terraform-state-access" \
  --policy-document "${S3_POLICY}"

# ---------------------------------------------------------------------------
# backend.hcl
# ---------------------------------------------------------------------------

echo "==> Generating backend.hcl..."

cat > backend.hcl <<EOF
bucket  = "${BUCKET}"
region  = "${REGION}"
key     = "proxy/terraform.tfstate"
encrypt = true
EOF

echo "    backend.hcl written."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo ""
echo "==> Bootstrap complete. Set these as GitHub Actions environment secrets"
echo "    under Settings → Environments → production:"
echo ""
echo "    ROLE_ARN:            ${ROLE_ARN}"
echo "    STATE_BUCKET:        ${BUCKET}"
echo "    STATE_BUCKET_REGION: ${REGION}"
echo ""
echo "    Then run: terraform init -backend-config=backend.hcl"
