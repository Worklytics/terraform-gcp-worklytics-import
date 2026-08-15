# Worklytics Import from GCP Terraform Module

[![Latest Release](https://img.shields.io/github/v/release/Worklytics/terraform-gcp-worklytics-import)](https://github.com/Worklytics/terraform-gcp-worklytics-import/releases/latest)
[![tests](https://img.shields.io/github/actions/workflow/status/Worklytics/terraform-gcp-worklytics-import/terraform_integration.yaml?label=tests)](https://github.com/Worklytics/terraform-gcp-worklytics-import/actions?query=branch%3Amain)

This module creates infra to support importing data from [Google Cloud Storage] into Worklytics.

It is intended for **non-proxy** Worklytics customers (files or dumps in your GCP project that
Worklytics should pull). If you use Worklytics with a [Psoxy] proxy, do not use this module for
that path: the [proxy Terraform modules] already provide equivalent functionality for connecting
sanitized data to Worklytics.

It is intended for the [Terraform Registry](https://registry.terraform.io/modules/Worklytics/worklytics-import/gcp/latest)
(`Worklytics/worklytics-import/gcp`).

If it does not meet your needs, feel free to directly copy the `main.tf` file into your own Terraform
configuration and adapt it to your requirements.

## What it provisions

1. **Optional storage** — a GCS bucket, unless you pass an existing `bucket_name`. Additional
   ingest locations can be passed via `import_buckets`.
2. **IAM** so your Worklytics tenant service account can read objects in each import bucket
   (`roles/storage.objectViewer` by default).
3. **Optional export** — if `enable_export` is true, also grant write access
   (`roles/storage.objectAdmin` by default) on the same bucket(s) and emit export-connection
   instructions.

Worklytics then reads objects from the bucket as your tenant's GCP service account (and may write
exports to it if you enabled that).

## Usage

from Terraform registry (once published):
```hcl
module "worklytics-import" {
  source  = "Worklytics/worklytics-import/gcp"
  version = "~> 0.1.0"

  # email of your Worklytics Tenant SA (obtain from the Worklytics app)
  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
}
```

via GitHub:
```hcl
module "worklytics-import" {
  source = "git::https://github.com/worklytics/terraform-gcp-worklytics-import/?ref=v0.1.0"

  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
}
```

The calling configuration must declare a `google` provider (this module does not configure
providers, so it can be composed into an existing GCP workspace). The provider's project is used
when this module creates a bucket.

```hcl
provider "google" {
  project = var.project_id
}
```

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `worklytics_tenant_sa_email` | yes | | Email of the Worklytics tenant GCP SA |
| `bucket_name` | no | `null` | Reuse this bucket for the primary zone; otherwise one is created |
| `import_buckets` | no | `[]` | Extra existing buckets to grant access on |
| `location` | no | `US` | Region / multi-region used only when creating a bucket |
| `enable_export` | no | `false` | Also grant write IAM and emit export TODOs |
| `bucket_iam_role` | no | `roles/storage.objectViewer` | Role granted for import (read) |
| `bucket_write_iam_role` | no | `roles/storage.objectAdmin` | Role granted when `enable_export` is true |
| `resource_name_prefix` | no | `worklytics-import-` | Prefix for a created bucket name |
| `force_destroy` | no | `false` | Allow destroying a created bucket that still has objects |

Your Worklytics tenant identity is the **email** of the tenant's GCP service account. Obtain it
from the Worklytics app.

## Outputs

#### `bucket_name` / `bucket_url`
The primary GCS bucket used as the import landing zone (created or reused).

#### `import_buckets`
Map of every import landing zone (the primary zone plus any `import_buckets` inputs), keyed by
target key.

#### `todo_markdown`
Rendered when `todos_as_outputs = true`.

## Compatibility

This module is meant for use with Terraform 1.3+ and the `hashicorp/google` provider `>= 5.0`
(tested against 5.x, 6.x, and 7.x). This module does not configure provider blocks; the caller
must.

If you find incompatibilities, please open an issue.

## Usage Tips

### Existing bucket

Pass `bucket_name` to skip bucket creation and only grant Worklytics access:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/gcp"

  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  bucket_name                = "my-existing-bucket"
}
```

### Multiple import buckets

Keep the singular variable for the primary landing zone and pass extra existing buckets:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/gcp"

  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  bucket_name                = "worklytics-import"

  import_buckets = [
    "worklytics-import-hris",
    "worklytics-import-calendar",
  ]
}
```

If `import_buckets` is set and `bucket_name` is omitted, only the list is used (no extra created
primary).

### Also allow exports to the same bucket(s)

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/gcp"

  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  enable_export              = true
}
```

That grants `roles/storage.objectAdmin` in addition to the import read role, and adds export
connection instructions to the TODO file.

### Permissions granted to Worklytics

| Role | When | Why |
|------|------|-----|
| Storage Object Viewer | always (default `bucket_iam_role`) | List and read objects for ingest |
| Storage Object Admin | `enable_export = true` | Write/overwrite export objects |

Worklytics authenticates as `worklytics_tenant_sa_email`. No workload identity federation is
required: both Worklytics and the bucket are in GCP.

**Using a custom role instead:**

```hcl
resource "google_project_iam_custom_role" "worklytics_import_reader" {
  role_id     = "worklyticsImportReader"
  title       = "Worklytics Import Reader"
  permissions = [
    "storage.objects.get",
    "storage.objects.list",
  ]
}

module "worklytics-import" {
  source = "Worklytics/worklytics-import/gcp"

  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  bucket_iam_role            = google_project_iam_custom_role.worklytics_import_reader.id
}
```

## Development

This module is written and maintained by [Worklytics, Co.](https://worklytics.co/) and intended to
guide our customers in setting up their own infra to import data from Google Cloud Storage into
Worklytics.

As this is [published as a Terraform module](https://developer.hashicorp.com/terraform/registry/modules/publish),
we will strive to follow [standard Terraform module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
and [style conventions](https://developer.hashicorp.com/terraform/language/syntax/style).

See [examples/basic/](examples/basic/) for a simple example of how to use this module.

### Releasing

Registry versions are **git tags** (`vX.Y.Z`) on `main`, not GitHub Releases. After a change is on
`main` and CI is green:

```bash
./tools/release.sh v0.1.0 --wait
```

That tags the current `origin/main` commit and pushes the tag. The tag-triggered workflow creates
the GitHub Release (notes / README badge). First-time listing on
[registry.terraform.io](https://registry.terraform.io/modules/Worklytics/worklytics-import/gcp)
is a one-time Publish in the HashiCorp UI (`Worklytics/worklytics-import/gcp`); later tags are
picked up by the Registry webhook.

### Tests

| Workflow | What it covers |
|----------|----------------|
| `terraform_lint.yaml` | `terraform fmt -check` |
| `terraform_validate.yaml` | `terraform init` / `validate` on `examples/basic`, plus `terraform test` unit tests |
| `terraform_integration.yaml` | Apply in the CI GCP project, then read an object as the stand-in Worklytics identity |
| `terraform_security.yaml` | Trivy IaC scan |

Unit tests live in [`tests/`](tests/) and use Terraform's native test framework with a mocked
`google` provider (no cloud credentials).

Integration tests authenticate to **GCP** (GitHub → WIF) to apply this module and to impersonate
the stand-in Worklytics tenant SA. Required GitHub secrets (public repo) or variables (private
repo):

| Name | Purpose |
|------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GitHub Actions WIF provider |
| `GCP_SERVICE_ACCOUNT` | CI agent SA (e.g. `gh-actions-tf-gcp-import@...`) |

The CI agent SA must be able to create buckets in `worklytics-ci` and impersonate the stand-in
tenant SA (`w8s-import-tf-ci@worklytics-ci.iam.gserviceaccount.com`). That sandbox is provisioned
by `worklytics-infra` (`src/development`).

(c) 2026 Worklytics, Co

[Google Cloud Storage]: https://cloud.google.com/storage
[Psoxy]: https://github.com/Worklytics/psoxy
[proxy Terraform modules]: https://github.com/Worklytics/psoxy
