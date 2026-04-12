# QuickProxy — AWS SOCKS Proxy Infrastructure

Reproducible AWS EC2 SOCKS proxy via Terraform and GitHub Actions, portable across account rotations.

## Overview

This project provisions a lightweight EC2 instance on AWS free tier that acts as a SOCKS proxy, accessible via an SSH tunnel routed through AWS SSM Session Manager. Infrastructure is fully managed by Terraform; the GitHub Actions pipeline handles provisioning, destruction, and instance start/stop without any long-lived AWS credentials.

## How it works

```
Mac → AWS SSM tunnel → EC2 instance → internet
          (no open ports)     (SOCKS proxy on :1080)
```

- **No long-lived AWS credentials** — GitHub Actions authenticates via OIDC
- **No open inbound ports** — SSM Session Manager provides the transport
- **Least-privilege client access** — proxy users assume a dedicated IAM role with SSM-only permissions; no infra access
- **Free tier** — t3.micro, no Elastic IP
- **Portable** — fully reproducible on a new AWS account via bootstrap script

## Quick Start

**Admin (bootstrap & infrastructure):**
1. [First-time setup & account rotation](docs/runbook.md)
2. [SSH key generation & multi-machine access](docs/ssh-key-setup.md)

**Client (connecting to the proxy):**
3. [Local Mac setup — AWS profile, SSH config, SOCKS proxy](docs/local-mac-setup.md)
4. [Finding the instance IP after start](docs/ip-discovery.md)

## Repository structure

```
.github/workflows/
  terraform.yml     # validate, plan, apply, destroy
  proxy.yml         # start, stop, status
terraform/
  main.tf           # provider and backend config
  variables.tf      # input variables
  outputs.tf        # instance ID, public IP, role ARN
  network.tf        # VPC, subnet, IGW, route table, security group
  ec2.tf            # EC2 instance with SSM and multi-key SSH support
  iam.tf            # GitHub OIDC role, client role + base user, EC2 instance profile
  templates/
    user-data.sh.tpl  # SSH key injection at instance launch
scripts/
  bootstrap.sh      # one-time AWS account setup
docs/
  runbook.md        # first-time setup and account rotation guide
  ssh-key-setup.md  # SSH key generation and multi-machine support
  local-mac-setup.md # Mac prerequisites, SSH config, SOCKS proxy
  ip-discovery.md   # finding the instance IP
```

## Pipeline

| Workflow | Trigger | Jobs |
|---|---|---|
| Terraform | Push to `main` (terraform files) or manual | validate → plan → approve → apply |
| Terraform | Manual (`action: destroy`) | validate → plan → approve → destroy |
| Proxy | Manual | start / stop / status |

## Prerequisites

- AWS account (free tier)
- Terraform >= 1.7.0
- AWS CLI + [Session Manager plugin](docs/local-mac-setup.md#aws-session-manager-plugin)
- SSH key pair — see [ssh-key-setup.md](docs/ssh-key-setup.md)
