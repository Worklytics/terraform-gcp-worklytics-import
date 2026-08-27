# Basic example (module development / CI)

This directory is **not** a production starter. It exists so we can `terraform apply` the module
from a local checkout (GitHub Actions and local iteration).

- `source = "../../"` tests the code in this repo, not a published version.
- `backend "local"` keeps CI state on the runner. **Do not use a local backend in
  production.**

Customer-facing usage (Terraform Registry source, your own providers and remote state) is in:

- the [root README](../../README.md)
- [examples/basic-remote](../basic-remote/)

## Usage for Development

Within `examples/basic/` (eg, here), create a `terraform.tfvars` file with the following content,
customizing GCP project and Worklytics tenant SA email as needed.

Omit `bucket_name` to have the module create a bucket; set it to reuse one.

```hcl
project_id                 = "my-gcp-project"
worklytics_tenant_sa_email = "tenant@my-project.iam.gserviceaccount.com"
# bucket_name              = "my-existing-bucket" # optional; omit to create
resource_name_prefix       = "my-worklytics-data-import-" # Optional
```

Then test the example:

```shell
terraform init
terraform apply
```
