# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Added
- Initial module to set up a GCS landing zone for importing data into Worklytics.
- Optional creation of a GCS bucket; an existing name is reused when provided. Additional
  ingest locations via `import_buckets`.
- IAM for the Worklytics tenant GCP service account (`roles/storage.objectViewer` by default).
- Optional `enable_export` to also grant `roles/storage.objectAdmin` and emit export TODOs.
- Native `terraform test` unit tests (mocked `google` provider) and a GitHub Actions integration
  test that applies the module in GCP and reads an object as the stand-in Worklytics identity.
- Maintainer release helper (`tools/release.sh`) that tags `origin/main` only after required CI
  checks pass.
- Requires Terraform 1.3+ and `hashicorp/google` >= 5.0.
