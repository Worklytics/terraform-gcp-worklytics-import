locals {
  bucket_name_prefix = trimsuffix(replace(lower(var.resource_name_prefix), "_", "-"), "-")

  # Primary singular zone: default create-one path, or when the caller set the singular name.
  include_primary = length(var.import_buckets) == 0 || var.bucket_name != null

  extra_buckets = [
    for name in var.import_buckets : name if name != var.bucket_name
  ]

  import_targets_list = concat(
    local.include_primary ? [{
      key         = "primary"
      bucket_name = var.bucket_name
    }] : [],
    [
      for name in local.extra_buckets : {
        # Namespace so a bucket literally named "primary" cannot collide with the reserved key.
        key         = "bucket:${name}"
        bucket_name = name
      }
    ]
  )

  import_targets = {
    for loc in local.import_targets_list : loc.key => {
      key           = loc.key
      bucket_name   = loc.bucket_name
      create_bucket = loc.bucket_name == null
    }
  }

  create_buckets = {
    for k, t in local.import_targets : k => t if t.create_bucket
  }
}

resource "random_id" "bucket" {
  for_each = local.create_buckets

  # 4 bytes → 8 hex chars; with the prefix this is a globally unique GCS bucket name.
  byte_length = 4
}

# Trivy IDs as of 2026 (AVD-GCP-0001 / AVD-GCP-0088 are stale):
#   GCP-0066 / AVD-GCP-0066 CMEK — optional via kms_crypto_key_name
#   GCP-0077 / AVD-GCP-0077 access logs — optional via bucket_access_logs_destination
#   GCP-0078 versioning — on by default via enable_versioning
#trivy:ignore:AVD-GCP-0066 CMEK is optional; pass kms_crypto_key_name to enable.
#trivy:ignore:AVD-GCP-0077 Access logging is optional; pass bucket_access_logs_destination for prod.
resource "google_storage_bucket" "import" {
  for_each = local.create_buckets

  name                        = "${local.bucket_name_prefix}-${random_id.bucket[each.key].hex}"
  project                     = var.project_id
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"

  versioning {
    enabled = var.enable_versioning
  }

  dynamic "logging" {
    for_each = var.bucket_access_logs_destination != null ? [var.bucket_access_logs_destination] : []
    content {
      log_bucket = logging.value
    }
  }

  dynamic "encryption" {
    for_each = var.kms_crypto_key_name != null ? [var.kms_crypto_key_name] : []
    content {
      default_kms_key_name = encryption.value
    }
  }
}

locals {
  resolved_import_targets = {
    for k, t in local.import_targets : k => {
      key         = k
      bucket_name = t.create_bucket ? google_storage_bucket.import[k].name : t.bucket_name
      created     = t.create_bucket
    }
  }

  # Prefer the reserved primary key; otherwise the first list-only target (caller order, not sort).
  primary_import_key = contains(keys(local.resolved_import_targets), "primary") ? "primary" : local.import_targets_list[0].key
  primary_import     = local.resolved_import_targets[local.primary_import_key]
}

# Worklytics import requires get + list on objects in the customer bucket.
# `roles/storage.objectViewer` is the default (PoLP). This module is import-only
# (Customer Premises → Worklytics); it does not grant write for data export.
resource "google_storage_bucket_iam_member" "worklytics" {
  for_each = local.resolved_import_targets

  bucket = each.value.bucket_name
  member = "serviceAccount:${var.worklytics_tenant_sa_email}"
  role   = var.bucket_iam_role
}

locals {
  import_todo_rows = join("\n", [
    for k, t in local.resolved_import_targets :
    "  - ${k}: `gs://${t.bucket_name}`"
  ])

  todo_content = <<EOT
# Configure Data Import in Worklytics

This connection pulls files **from your GCS bucket into Worklytics**
(Customer Premises → Worklytics). It is not a data export.

1. Ensure you're authenticated with Worklytics. Either sign-in at [https://${var.worklytics_host}](https://${var.worklytics_host})
  with your organization's SSO provider *or* request OTP link from your Worklytics support.
2. Visit `https://${var.worklytics_host}/analytics/connect/gcs-import?bucket=${local.primary_import.bucket_name}`
3. Review any additional settings and click "Create Data Import". Repeat for any extra buckets.

Import landing zones granted to Worklytics (read):
${local.import_todo_rows}

Alternatively, you may follow the manual instructions below:

1. Visit [https://${var.worklytics_host}/analytics/connect](https://${var.worklytics_host}/analytics/connect)
  (or login into Worklytics, and navigate to Connect → Google Cloud Storage import).
2. Create a new Google Cloud Storage import connection with the following values:
  - Bucket: ${local.primary_import.bucket_name}
  - Worklytics tenant identity: ${var.worklytics_tenant_sa_email}

Write objects you want Worklytics to ingest into the bucket(s). Worklytics authenticates as the
GCP service account above and reads those objects.
EOT
}

resource "local_file" "todo" {
  count = var.todos_as_local_files ? 1 : 0

  filename = var.todo_file_path
  content  = local.todo_content
}
