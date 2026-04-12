variable "github_repo" {
  type        = string
  description = "GitHub repository in \"owner/repo\" format — used to scope the OIDC trust policy (e.g. \"brunnerf/QuickProxy\")"
}

variable "additional_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into EC2 instances at launch — passed through to regional roots via the pipeline"
}
