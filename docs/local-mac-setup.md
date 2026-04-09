# Local Mac Setup

This document covers the prerequisites and local test commands for working with this repository on macOS.

## Prerequisites

Install all tools before working with this repository:

### AWS CLI

```bash
brew install awscli
```

Verify: `aws --version`

### AWS Session Manager Plugin

Required for SSM-based SSH tunnelling (the SOCKS proxy transport).

Install using the official AWS package (recommended — brew cask is deprecated):

```bash
# Apple Silicon (M1/M2/M3)
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o session-manager-plugin.pkg
sudo installer -pkg session-manager-plugin.pkg -target /
rm session-manager-plugin.pkg

# Intel Mac
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/session-manager-plugin.pkg" -o session-manager-plugin.pkg
sudo installer -pkg session-manager-plugin.pkg -target /
rm session-manager-plugin.pkg
```

The installer places the binary in `/usr/local/sessionmanagerplugin/bin/` which is not on the default PATH. Create a symlink so it's accessible system-wide:

```bash
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin
```

Verify: `session-manager-plugin --version`

### Terraform

```bash
brew install terraform
```

Verify: `terraform version`

### tflint

```bash
brew install tflint
```

After installing, download the AWS ruleset plugin (one-time, per machine):

```bash
tflint --init --chdir=terraform/
```

### checkov

```bash
brew install checkov
```

## Local Testing

Run these three checks from the **repo root** before pushing, in this order:

### 1. Formatting check

```bash
terraform fmt -check terraform/
```

Verifies all `.tf` files are formatted according to the Terraform style conventions. Fix with `terraform fmt terraform/` if it reports any files.

### 2. Linting

```bash
tflint --chdir=terraform/
```

Checks for AWS-specific best practices and deprecated configurations using the tflint AWS ruleset plugin.

### 3. Security scan

```bash
checkov -d terraform/
```

Scans all `.tf` files for security misconfigurations (e.g. open security groups, unencrypted storage). Review any reported findings — not all checks are blockers for this project.

## AWS Credentials (local apply)

For local `terraform apply` you need AWS credentials configured. Use AWS SSO if available:

```bash
aws configure sso       # one-time setup
aws sso login --profile <profile-name>
export AWS_PROFILE=<profile-name>
```

Or configure static credentials (not recommended for long-term use):

```bash
aws configure
```

## Backend Initialisation

`backend.hcl` is gitignored and must be created locally before running `terraform init`. See the architecture doc for the required format. Then from the `terraform/` directory:

```bash
terraform init -backend-config=../backend.hcl
```

---

## SSH config for SSM transport

Add this block to `~/.ssh/config`:

```
Host i-*
  User ec2-user
  IdentityFile ~/.ssh/quickproxy_key
  ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p
  StrictHostKeyChecking no
```

This routes any SSH connection to an instance ID (`i-*`) through the SSM tunnel. No open ports on the EC2 instance are required.

---

## Starting the SOCKS proxy

Add this alias to your `~/.zshrc` or `~/.bashrc`:

```bash
export PROXY_INSTANCE_ID="i-0abc1234def567890"  # replace with your instance ID
alias proxy-connect='ssh -D 1080 -N -f $PROXY_INSTANCE_ID'
```

Reload your shell:
```bash
source ~/.zshrc
```

To start the proxy:
1. Start the EC2 instance: **Actions → Proxy → Run workflow** → `start`
2. Wait ~30 seconds
3. Run `proxy-connect` — the command returns immediately, tunnel runs in the background on `localhost:1080`

---

## macOS SOCKS proxy configuration

**System Settings → Network → select active connection (Wi-Fi or Ethernet) → Details → Proxies → SOCKS Proxy**

- Enable: ✅
- Server: `127.0.0.1`
- Port: `1080`

Click OK and Apply. Chrome and Safari use the macOS system proxy automatically — no browser extension needed.

---

## Verification

Visit `https://whatismyipaddress.com/` — the IP should match the instance's public IP from the `status` job (see [docs/ip-discovery.md](ip-discovery.md)).

---

## Deactivating the proxy

1. Uncheck **SOCKS Proxy** in System Settings → Network → Details → Proxies
2. Kill the background SSH tunnel:
   ```bash
   pkill -f "ssh -D 1080"
   ```

Always deactivate when done — leaving it active with a stopped instance will break your internet connection.
