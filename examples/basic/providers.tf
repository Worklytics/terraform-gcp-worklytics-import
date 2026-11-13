terraform {
  # Local state is convenient for iterating on this repo and for GitHub Actions e2e.
  # Do NOT use a local backend in production; use remote state (Terraform Cloud,
  # GCS, S3, etc.) so state is shared, locked, and backed up.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0"
    }
  }
}

# In real use you likely already have this provider block in the root module.
# Do not force `project` here: WIF credentials impersonate a SA in the provider
# project. Created buckets use module.project_id.
provider "google" {
}
