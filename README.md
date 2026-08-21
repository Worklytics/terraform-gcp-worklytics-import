# Worklytics Import from GCP Terraform Module

**Direction: Customer Premises → Worklytics.** Worklytics *reads* files you place in a GCS bucket
in your project. This module does **not** send data the other way.

[![Latest Release](https://img.shields.io/github/v/release/Worklytics/terraform-gcp-worklytics-import)](https://github.com/Worklytics/terraform-gcp-worklytics-import/releases/latest)
[![tests](https://img.shields.io/github/actions/workflow/status/Worklytics/terraform-gcp-worklytics-import/terraform_integration.yaml?label=tests)](https://github.com/Worklytics/terraform-gcp-worklytics-import/actions?query=branch%3Amain)

This module creates infra so Worklytics can **import** (pull) data from [Google Cloud Storage]
into the Worklytics tenant. For the reverse path (Worklytics **exporting** into your bucket),
use [`Worklytics/worklytics-export/gcp`](https://registry.terraform.io/modules/Worklytics/worklytics-export/gcp/latest) instead.

```
  Your GCP project                         Worklytics
  ┌─────────────────────┐                  ┌──────────┐
  │  GCS bucket         │  objectViewer    │  ingest  │
  │  (files you write)  │ ───────────────► │          │
  └─────────────────────┘   tenant SA      └──────────┘
```

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
2. **Read IAM** so your Worklytics tenant service account can list and get objects in each import
   bucket (`roles/storage.objectViewer` by default). No write/export roles are granted.

Worklytics then reads objects from the bucket as your tenant's GCP service account.

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
providers, so it can be composed into an existing GCP workspace). A bucket is created in
the provider's project unless you pass `project_id`.

```hcl
provider "google" {
  project = var.project_id
  # Optional: labels for buckets this module creates (google provider 7.x)
  # default_labels = { purpose = "worklytics-import" }
}
```

If you authenticate as a service account in one project (for example CI WIF) and create the
bucket in another via `project_id`, impersonated ADC can fail on bucket create: Storage uses
the bucket project as quota project and token refresh then looks up the SA there. Mint an
access token (`gcloud auth print-access-token`) and set `GOOGLE_OAUTH_ACCESS_TOKEN` for that
apply, or create the bucket in the same project as the authenticated identity.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `worklytics_tenant_sa_email` | yes | | Email of the Worklytics tenant GCP SA |
| `bucket_name` | no | `null` | Reuse this bucket for the primary zone; otherwise one is created |
| `import_buckets` | no | `[]` | Extra existing buckets to grant read access on |
| `project_id` | no | provider project | Project for a created bucket |
| `location` | no | `US` | Region / multi-region used only when creating a bucket |
| `enable_versioning` | no | `true` | Object versioning on a created bucket |
| `bucket_access_logs_destination` | no | `null` | Log bucket for access logs (recommended in prod) |
| `kms_crypto_key_name` | no | `null` | Optional CMEK for a created bucket |
| `bucket_iam_role` | no | `roles/storage.objectViewer` | Role granted for import (read) |
| `resource_name_prefix` | no | `worklytics-import-` | Prefix for a created bucket name |
| `force_destroy` | no | `false` | Allow destroying a created bucket that still has objects |
| `worklytics_host` | no | `app.worklytics.co` | Host used in generated connection URLs |
| `todos_as_outputs` | no | `false` | Render setup TODOs as the `todo_markdown` output |
| `todos_as_local_files` | no | `true` | Write a local TODO markdown file |
| `todo_file_path` | no | `TODO - configure import in worklytics.md` | Path for that TODO file |

Your Worklytics tenant identity is the **email** of the tenant's GCP service account. Obtain it
from the Worklytics app.

## Outputs

#### `bucket_name` / `bucket_url`
The primary GCS bucket used as the import landing zone (created or reused).

#### `import_buckets`
Map of every import landing zone. The created-or-singular zone is keyed `primary`; extra
`import_buckets` entries are keyed `bucket:<name>`.

#### `todo_markdown`
Rendered when `todos_as_outputs = true`.

## Compatibility

This module is meant for use with Terraform 1.3+ and the `hashicorp/google` provider `>= 7.0`.
This module does not configure provider blocks; the caller must. Use `default_labels` on the
provider if you want labels on a bucket this module creates.

If you find incompatibilities, please open an issue.

## Usage Tips

### Existing bucket

Pass `bucket_name` to skip bucket creation and only grant Worklytics read access:

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
primary). The first list entry is treated as primary for outputs and connection URLs.

### Created-bucket hardening

A bucket created by this module has uniform bucket-level access, public access prevention, and
object versioning on by default (`enable_versioning = false` to turn versioning off).

Access logging and CMEK are **optional** so this module does not invent a log bucket or KMS key.
For production, pass them:

```hcl
module "worklytics-import" {
  source = "Worklytics/worklytics-import/gcp"

  worklytics_tenant_sa_email       = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"
  bucket_access_logs_destination   = "my-org-gcs-access-logs"
  kms_crypto_key_name              = "projects/my-project/locations/us/keyRings/import/cryptoKeys/gcs"
}
```

This module does **not** grant the IAM those features need:

- **Access logs:** the destination bucket must allow `group:cloud-storage-analytics@google.com`
  to create objects (`roles/storage.objectCreator` or equivalent).
- **CMEK:** the Cloud Storage service agent of the bucket's project must have
  `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key.

### Permissions granted to Worklytics

| Role | When | Why |
|------|------|-----|
| Storage Object Viewer | always (default `bucket_iam_role`) | List and read objects for ingest |

Worklytics authenticates as `worklytics_tenant_sa_email`. No workload identity federation is
required: both Worklytics and the bucket are in GCP.

This module does not grant write access. If you also need Worklytics to **export** into GCS,
compose [`Worklytics/worklytics-export/gcp`](https://registry.terraform.io/modules/Worklytics/worklytics-export/gcp/latest)
in the same configuration (optionally on a different bucket).

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
the stand-in Worklytics tenant SA. Identifiers are GitHub Actions **variables** (not secrets —
secrets redact logs). Set them in repo settings / `worklytics-infra`, not in the workflow file:

| Name | Purpose |
|------|---------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GitHub Actions WIF provider resource name |
| `GCP_SERVICE_ACCOUNT` | CI agent SA email |
| `EXAMPLE_TENANT_SA_EMAIL` | Stand-in Worklytics tenant SA for the round-trip |
| `CI_TF_PROJECT` | GCP project where e2e creates buckets |

The CI agent SA must be able to create buckets in `CI_TF_PROJECT` and impersonate the stand-in
tenant SA. That sandbox is provisioned by `worklytics-infra` (`src/development`).

(c) 2026 Worklytics, Co

[Google Cloud Storage]: https://cloud.google.com/storage
[Psoxy]: https://github.com/Worklytics/psoxy
[proxy Terraform modules]: https://github.com/Worklytics/psoxy
