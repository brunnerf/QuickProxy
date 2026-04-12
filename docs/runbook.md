# QuickProxy — Account Rotation Runbook

Follow this runbook to set up QuickProxy on a brand new AWS account. From start to first working proxy connection: ~15 minutes.

## Prerequisites

Install the following tools before starting:

```bash
# AWS CLI
brew install awscli

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Session Manager plugin (required for SSH over SSM)
# Apple Silicon (M1/M2/M3):
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o session-manager-plugin.pkg
sudo installer -pkg session-manager-plugin.pkg -target /
rm session-manager-plugin.pkg

# Intel Mac:
# curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/session-manager-plugin.pkg" -o session-manager-plugin.pkg
# sudo installer -pkg session-manager-plugin.pkg -target /
# rm session-manager-plugin.pkg

# Add to PATH (required on both architectures):
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin

# Static analysis (optional but recommended)
brew install tflint
brew install checkov
```

Verify installations:
```bash
aws --version
terraform -version
session-manager-plugin --version
```

Configure AWS credentials for the new account:
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region, output format (json)
```

---

## Step 1 — Generate SSH key

See [docs/ssh-key-setup.md](ssh-key-setup.md) for full instructions.

Quick version:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/quickproxy_key -C "quickproxy-<machine-name>"
cat ~/.ssh/quickproxy_key.pub  # copy this — needed in Step 3
```

---

## Step 2 — Run bootstrap script

From the repo root:
```bash
bash scripts/bootstrap.sh <aws-region> brunnerf/QuickProxy
```

Example:
```bash
bash scripts/bootstrap.sh eu-west-1 brunnerf/QuickProxy
```

The script creates:
- S3 bucket for Terraform state
- GitHub OIDC provider in AWS IAM
- IAM role with required permissions
- `backend.hcl` in the repo root (gitignored)

At the end it prints the values you need for Step 3.

---

## Step 3 — Set GitHub Actions secrets

Go to the repository: **Settings → Environments → production → Environment secrets**

Add these secrets:

| Secret | Value | Where to get it |
|---|---|---|
| `ROLE_ARN` | `arn:aws:iam::<account-id>:role/github-oidc-role` | Bootstrap script output |
| `STATE_BUCKET` | `terraform-state-<account-id>` | Bootstrap script output |
| `STATE_BUCKET_REGION` | `eu-west-1` | Region where the S3 state bucket was created |
| `QUICKPROXY_GITHUB_REPO` | `brunnerf/QuickProxy` | Your GitHub repository in owner/repo format |
| `ADDITIONAL_PUBLIC_KEYS` | `["ssh-ed25519 AAAA... quickproxy-mac"]` | Output of `cat ~/.ssh/quickproxy_key.pub` wrapped in `["..."]` |

---

## Step 4 — Commit provider lock files (optional but recommended)

The pipeline initialises Terraform itself on every run, so **this step is not required** for the pipeline to work. However, committing lock files pins provider versions so CI never silently upgrades them.

From the repo root:

```bash
for dir in terraform/global terraform/eu-central-1 terraform/eu-west-2 terraform/us-east-1; do
  terraform -chdir=$dir init -backend=false -input=false
done
git add terraform/global/.terraform.lock.hcl \
        terraform/eu-central-1/.terraform.lock.hcl \
        terraform/eu-west-2/.terraform.lock.hcl \
        terraform/us-east-1/.terraform.lock.hcl
git commit -m "chore: add terraform lock files for all roots"
git push
```

Skip this and go straight to Step 5 if you just want to get the proxy running.

---

## Step 5 — Apply global IAM first, then each region

IAM resources must exist before EC2 instances can be created (the module looks up the instance profile by name).

**5a — Apply global:**
In GitHub: **Actions → Terraform → Run workflow**
- region: `global`
- action: `apply`

**5b — Apply each region** (repeat for eu-central-1, eu-west-2, us-east-1):
In GitHub: **Actions → Terraform → Run workflow**
- region: `eu-central-1` (then eu-west-2, then us-east-1)
- action: `apply`

Instance IDs are no longer stored as GitHub secrets — the proxy workflow looks them up dynamically by tag at runtime.

---

## Step 6 — Create client access key

Terraform creates the `quickproxy-base` IAM user but intentionally does not create the access key (to keep the secret out of Terraform state). Run this once, using whatever credentials you used for bootstrap:

```bash
aws iam create-access-key --user-name quickproxy-base
```

Note the `AccessKeyId` and `SecretAccessKey` from the output — AWS will not show the secret again.

Get the client role ARN from the Terraform output:
```bash
cd terraform
terraform output client_role_arn
```

Share both values with anyone who needs client access to the proxy. Each client machine stores the credentials in `~/.aws/credentials` and the role config in `~/.aws/config` — see [docs/local-mac-setup.md](local-mac-setup.md#aws-profile-setup).

---

## Step 7 — Configure local Mac

See [docs/local-mac-setup.md](local-mac-setup.md) for full instructions covering:
- SSH config for SSM transport
- SOCKS proxy activation alias
- macOS system proxy settings

---

## Step 8 — Verify

1. Trigger **Actions → Proxy → Run workflow** → `start`
2. Wait ~30 seconds, then trigger → `status` — note the public IP
3. Run `proxy-connect` (see local-mac-setup.md)
4. Visit `https://whatismyipaddress.com/` — IP should match the instance

---

## After instance replacement

The EC2 instance is replaced whenever you trigger apply with `replace_instance: true` or run destroy followed by apply. A new instance gets a **new instance ID** — update these two places every time:

1. **GitHub secret** — Settings → Environments → production → `INSTANCE_ID` → update to the new ID from the pipeline's Terraform output
2. **Local shell config** — update `PROXY_INSTANCE_ID` in `~/.zshrc` and reload:
   ```bash
   export PROXY_INSTANCE_ID="i-0new1234..."
   source ~/.zshrc
   ```

The SSH key also needs to be re-added to `authorized_keys` at launch — it is injected automatically via `user_data`, so as long as `ADDITIONAL_PUBLIC_KEYS` is set correctly in GitHub the new instance will have the right key from the start.

---

## Account rotation checklist

When switching to a new AWS account, repeat all steps above. Additionally:

1. Run `terraform init -reconfigure -backend-config=backend.hcl` after updating `backend.hcl` to point to the new account's bucket — this migrates Terraform to the new state backend.
2. Update all four GitHub secrets with the new account's values.
3. The old account's resources are abandoned — destroy them manually if needed to avoid charges.
