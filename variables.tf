variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-import-"
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = <<-EOT
    Email address of your Worklytics tenant's GCP service account (obtain from the Worklytics
    app). Worklytics uses this identity to read (and, if `enable_export` is set, write) objects
    in the import bucket(s).
  EOT

  validation {
    condition = can(regex(
      "^[a-zA-Z0-9._-]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$",
      var.worklytics_tenant_sa_email
    ))
    error_message = "`worklytics_tenant_sa_email` must be a GCP IAM service account email."
  }
}

variable "bucket_name" {
  type        = string
  description = <<-EOT
    Existing GCS bucket for the primary import landing zone. If null and this module is managing
    a primary zone, a bucket is created. Providing a name skips primary bucket creation; the
    module only grants Worklytics access.
  EOT
  default     = null
  nullable    = true

  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "`bucket_name` must be a valid GCS bucket name (3-63 chars, lowercase, numbers, dots, hyphens)."
  }
}

variable "import_buckets" {
  type        = list(string)
  description = <<-EOT
    Optional additional existing GCS buckets to grant Worklytics access to. Use this when the
    customer has several ingest locations. Names must refer to buckets that already exist.

    The singular `bucket_name` still describes the primary zone. A primary zone is managed when
    `bucket_name` is set *or* when this list is empty (the default create-one-bucket path). If
    this list is non-empty and `bucket_name` is null, only the list is used — no extra bucket is
    created.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for name in var.import_buckets :
      can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Each import_buckets value must be a valid GCS bucket name."
  }
}

variable "location" {
  type        = string
  description = <<-EOT
    Location for a GCS bucket created by this module (region or multi-region, e.g. `US` or
    `us-central1`). Ignored when no bucket is created.
  EOT
  default     = "US"
}

variable "force_destroy" {
  type        = bool
  description = <<-EOT
    If true, a bucket created by this module can be destroyed even when it contains objects.
    Defaults to false so customer data is not deleted by accident. CI should set this true.
  EOT
  default     = false
}

variable "enable_export" {
  type        = bool
  description = <<-EOT
    If true, also grant Worklytics write access (`bucket_write_iam_role`) on the same bucket(s)
    so they can receive data exports, and include export connection instructions in the TODOs.
    Import-only (the default) grants read access via `bucket_iam_role`.
  EOT
  default     = false
}

variable "bucket_iam_role" {
  type        = string
  description = <<-EOT
    IAM role to grant the Worklytics tenant service account on each import bucket (read path).
    Defaults to roles/storage.objectViewer.

    Minimum permissions required to ingest:
      - storage.objects.get
      - storage.objects.list

    If Worklytics must also write ingest checkpoints into the customer bucket, pass
    `roles/storage.objectAdmin` (or a custom role with create/delete) instead.
  EOT
  default     = "roles/storage.objectViewer"

  validation {
    condition = can(regex(
      "^(roles/|projects/[^/]+/roles/|organizations/[^/]+/roles/)[a-zA-Z0-9_.]+$",
      var.bucket_iam_role
    ))
    error_message = "bucket_iam_role must be a built-in role (roles/...) or a custom role (projects/{project}/roles/{id} or organizations/{org}/roles/{id})."
  }
}

variable "bucket_write_iam_role" {
  type        = string
  description = <<-EOT
    IAM role granted when `enable_export` is true. Defaults to roles/storage.objectAdmin (the
    Worklytics-documented export role).

    Minimum permissions required to export (PoLP):
      - storage.objects.create
      - storage.objects.delete  (GCS overwrite is delete+create)
      - storage.objects.list

    Ignored when `enable_export` is false. If this equals `bucket_iam_role`, a single binding
    is created.
  EOT
  default     = "roles/storage.objectAdmin"

  validation {
    condition = can(regex(
      "^(roles/|projects/[^/]+/roles/|organizations/[^/]+/roles/)[a-zA-Z0-9_.]+$",
      var.bucket_write_iam_role
    ))
    error_message = "bucket_write_iam_role must be a built-in role (roles/...) or a custom role (projects/{project}/roles/{id} or organizations/{org}/roles/{id})."
  }
}

variable "worklytics_host" {
  type        = string
  description = "Host of the Worklytics instance where the tenant resides (e.g. app.worklytics.co)."
  default     = "app.worklytics.co"
}

variable "todos_as_outputs" {
  type        = bool
  description = <<-EOT
    Whether to render TODOs as outputs (useful if you're using Terraform Cloud/Enterprise, or
    somewhere else where the filesystem is not readily accessible to you).
  EOT
  default     = false
}

variable "todos_as_local_files" {
  type        = bool
  description = "Whether to render TODOs as flat files."
  default     = true
}
