# Local Mac Setup — Client Connectivity

Everything needed on a client Mac to connect to the QuickProxy SOCKS proxy. No Terraform or admin AWS credentials required.

---

## Prerequisites

### AWS CLI

```bash
brew install awscli
```

Verify: `aws --version`

### AWS Session Manager Plugin

Required for SSM-based SSH tunnelling (the SOCKS proxy transport).

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

The installer places the binary outside the default PATH. Create a symlink:

```bash
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin
```

Verify: `session-manager-plugin --version`

### SSH key

Your SSH public key must be registered with the proxy instance before you can connect. If you are the admin setting up the first machine, this is handled during bootstrap. For a second machine, see [ssh-key-setup.md](ssh-key-setup.md).

---

## AWS Profile Setup

Client machines authenticate via a dedicated IAM user (`quickproxy-base`) whose only permission is to assume the `quickproxy-client-role`. All actual proxy operations run under that role using short-lived credentials.

You need the `AccessKeyId` and `SecretAccessKey` from the admin (created in the runbook at Step 6), and the `client_role_arn` from the Terraform output.

Add these two profiles to `~/.aws/config`:

```ini
[profile quickproxy-base]
aws_access_key_id     = <AccessKeyId>
aws_secret_access_key = <SecretAccessKey>
region                = eu-west-1

[profile quickproxy-client]
role_arn       = <client_role_arn>
source_profile = quickproxy-base
region         = eu-west-1
```

Verify the setup:

```bash
aws sts get-caller-identity --profile quickproxy-client
```

Expected output shows the assumed role ARN, not the base user.

---

## SSH Config for SSM Transport

Add this block to `~/.ssh/config`:

```
Host i-* mi-*
  User ec2-user
  IdentityFile ~/.ssh/quickproxy_key
  ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile quickproxy-client
  StrictHostKeyChecking no
```

This routes any SSH connection to an instance ID (`i-*`) through the SSM tunnel using the client profile. No open ports on the EC2 instance are required.

---

## Starting the SOCKS Proxy

Add this to `~/.zshrc` or `~/.bashrc`:

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

## macOS SOCKS Proxy Configuration

**System Settings → Network → select active connection (Wi-Fi or Ethernet) → Details → Proxies → SOCKS Proxy**

- Enable: ✅
- Server: `127.0.0.1`
- Port: `1080`

Click OK and Apply. Chrome and Safari use the macOS system proxy automatically — no browser extension needed.

---

## Verification

Visit `https://whatismyipaddress.com/` — the IP should match the instance's public IP from the `status` job (see [ip-discovery.md](ip-discovery.md)).

---

## Deactivating the Proxy

1. Uncheck **SOCKS Proxy** in System Settings → Network → Details → Proxies
2. Kill the background SSH tunnel:
   ```bash
   pkill -f "ssh -D 1080"
   ```

Always deactivate when done — leaving it active with a stopped instance will break your internet connection.
