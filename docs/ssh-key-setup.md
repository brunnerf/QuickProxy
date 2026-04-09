# SSH Key Setup

## Why SSH keys are needed

QuickProxy uses two layers of connectivity:

1. **SSM transport** — AWS Session Manager opens an encrypted tunnel from your Mac to the EC2 instance through the AWS API. This uses your AWS credentials, not SSH keys.
2. **SSH inner session** — SSH runs inside the SSM tunnel to authenticate you to the instance and set up the SOCKS proxy (`ssh -D`). This uses your SSH key.

Both layers are required. SSM gets you through the network without any open ports; SSH authenticates and creates the tunnel.

---

## Generating a key for this machine

```bash
ssh-keygen -t ed25519 -f ~/.ssh/quickproxy_key -C "quickproxy-<machine-name>"
```

Replace `<machine-name>` with something descriptive, e.g. `quickproxy-macbook-pro`.

This creates:
- `~/.ssh/quickproxy_key` — private key (never share this)
- `~/.ssh/quickproxy_key.pub` — public key (safe to share)

---

## Adding the key to the instance

The public key is injected into the EC2 instance at launch via `user_data`. It is configured as a GitHub Actions secret and passed to Terraform as a variable.

Get your public key:
```bash
cat ~/.ssh/quickproxy_key.pub
```

Set the `ADDITIONAL_PUBLIC_KEYS` secret in GitHub (**Settings → Environments → production**) with this format:
```
["ssh-ed25519 AAAA...your full key... quickproxy-macbook-pro"]
```

Note the outer brackets and quotes — this is HCL list syntax that Terraform expects.

---

## Adding a second machine

Each machine needs its own key pair — never copy private keys between machines.

On the second machine:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/quickproxy_key -C "quickproxy-<second-machine-name>"
cat ~/.ssh/quickproxy_key.pub
```

Update the `ADDITIONAL_PUBLIC_KEYS` secret to include both keys:
```
["ssh-ed25519 AAAA...key1... quickproxy-macbook-pro", "ssh-ed25519 AAAA...key2... quickproxy-imac"]
```

Then trigger **Actions → Terraform → Run workflow** with:
- action: `apply`
- replace_instance: `true`

The instance will be recreated with both keys in `authorized_keys`.
