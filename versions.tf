# HashiCorp module convention: Terraform / provider version constraints live in
# versions.tf. Provider *configuration* (credentials, default project) belongs in
# the caller's providers.tf; this module does not configure providers.
terraform {
  required_version = ">= 1.3, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}
