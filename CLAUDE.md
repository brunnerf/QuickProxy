# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository

This is the QuickProxy project — a reproducible AWS EC2 SOCKS proxy provisioned via Terraform and GitHub Actions CI/CD.

## Conventions

- Git remote: `git@github.com:brunnerf/QuickProxy.git`
- Default branch: `main`
- Pull requests are preferred over direct pushes to `main`

## Project-specific commands

```bash
# Local static analysis (run from repo root)
terraform fmt -check terraform/
tflint --chdir=terraform/
checkov -d terraform/

# Local apply (from terraform/ directory)
terraform init -backend-config=../backend.hcl
terraform plan
terraform apply
```
