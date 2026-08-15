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
        key         = name
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

#trivy:ignore:AVD-GCP-0001 Customer-managed encryption is left to consumers.
#trivy:ignore:AVD-GCP-0088 Access logging is left to consumers who have a log bucket.
resource "google_storage_bucket" "import" {
  for_each = local.create_buckets

  name                        = "${local.bucket_name_prefix}-${random_id.bucket[each.key].hex}"
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"

  labels = {
    purpose = "worklytics-import"
  }

  lifecycle {
    ignore_changes = [
      # don't conflict with labels customers might wish to add themselves
      labels,
    ]
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

  primary_import_key = contains(keys(local.resolved_import_targets), "primary") ? "primary" : sort(keys(local.resolved_import_targets))[0]
  primary_import     = local.resolved_import_targets[local.primary_import_key]

  # Roles to bind: always the import (read) role; write role too when export is enabled and distinct.
  bucket_roles = distinct(compact([
    var.bucket_iam_role,
    var.enable_export ? var.bucket_write_iam_role : null,
  ]))

  iam_members = {
    for pair in setproduct(keys(local.resolved_import_targets), local.bucket_roles) :
    "${pair[0]}:${pair[1]}" => {
      target_key  = pair[0]
      bucket_name = local.resolved_import_targets[pair[0]].bucket_name
      role        = pair[1]
    }
  }
}

# Worklytics import requires get + list on objects in the customer bucket.
# `roles/storage.objectViewer` is the default (PoLP). `enable_export` adds objectAdmin
# (documented for GCS export; overwrite is delete+create).
#trivy:ignore:AVD-GCP-0007 objectAdmin is the documented export role; import defaults to objectViewer
resource "google_storage_bucket_iam_member" "worklytics" {
  for_each = local.iam_members

  bucket = each.value.bucket_name
  member = "serviceAccount:${var.worklytics_tenant_sa_email}"
  role   = each.value.role
}

locals {
  import_todo_rows = join("\n", [
    for k, t in local.resolved_import_targets :
    "  - ${k}: `gs://${t.bucket_name}`"
  ])

  export_todo_content = <<EOT

# Configure Data Export in Worklytics (optional; enabled in this apply)

1. Visit `https://${var.worklytics_host}/analytics/data-export/connect?type=GOOGLE_CLOUD_STORAGE&bucket=${local.primary_import.bucket_name}`
2. Review dataset type and other settings, then click "Create Data Export".

The same Worklytics tenant service account was granted `${var.bucket_write_iam_role}` on the
bucket(s) above so exports can be written there.
EOT

  export_todo = var.enable_export ? local.export_todo_content : ""

  todo_content = <<EOT
# Configure Data Import in Worklytics

1. Ensure you're authenticated with Worklytics. Either sign-in at [https://${var.worklytics_host}](https://${var.worklytics_host})
  with your organization's SSO provider *or* request OTP link from your Worklytics support.
2. Visit `https://${var.worklytics_host}/analytics/data-import/connect?type=GOOGLE_CLOUD_STORAGE&bucket=${local.primary_import.bucket_name}`
3. Review any additional settings and click "Create Data Import". Repeat for any extra buckets.

Import landing zones granted to Worklytics:
${local.import_todo_rows}

Alternatively, you may follow the manual instructions below:

1. Visit [https://${var.worklytics_host}](https://${var.worklytics_host})
  (or login into Worklytics, and navigate to Manage --> Import Data).
2. Create a new Google Cloud Storage import connection with the following values:
  - Bucket: ${local.primary_import.bucket_name}
  - Worklytics tenant identity: ${var.worklytics_tenant_sa_email}

Write objects you want Worklytics to ingest into the bucket(s). Worklytics authenticates as the
GCP service account above and reads those objects.
${local.export_todo}
EOT
}

resource "local_file" "todo" {
  count = var.todos_as_local_files ? 1 : 0

  filename = "TODO - configure import in worklytics.md"
  content  = local.todo_content
}
