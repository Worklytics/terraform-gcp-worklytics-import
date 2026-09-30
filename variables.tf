variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-import-"

  validation {
    # Normalized prefix + "-" + 8 hex chars must be a valid GCS bucket name (3-63 chars).
    condition = (
      length(trimsuffix(replace(lower(var.resource_name_prefix), "_", "-"), "-")) >= 1
      && length(trimsuffix(replace(lower(var.resource_name_prefix), "_", "-"), "-")) <= 54
      && can(regex(
        "^[a-z0-9]([a-z0-9.-]{0,52}[a-z0-9])?$",
        trimsuffix(replace(lower(var.resource_name_prefix), "_", "-"), "-")
      ))
    )
    error_message = "`resource_name_prefix` (lowercased, underscores to hyphens, trailing hyphen stripped) must be 1-54 chars starting and ending with a letter or digit, using only letters, digits, hyphens, and dots."
  }
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = <<-EOT
    Email address of your Worklytics tenant's GCP service account (obtain from the Worklytics
    app). Worklytics uses this identity to *read* objects from the import bucket(s)
    (Customer Premises → Worklytics).
  EOT

  validation {
    condition = can(regex(
      "^[a-zA-Z0-9._-]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$",
      var.worklytics_tenant_sa_email
    ))
    error_message = "`worklytics_tenant_sa_email` must be a GCP IAM service account email."
  }
}

variable "existing_buckets_to_import" {
  type        = list(string)
  description = <<-EOT
    Existing GCS buckets to grant Worklytics read access. If empty (the default), this module
    creates one bucket. If non-empty, no bucket is created; the module only grants IAM on the
    named buckets. The first entry is used for singular outputs and connection URLs.
  EOT
  default     = []
}

variable "location" {
  type        = string
  description = <<-EOT
    Location for a GCS bucket created by this module (region or multi-region, e.g. `US` or
    `us-central1`). Ignored when no bucket is created.
  EOT
  default     = "US"
}

variable "project_id" {
  type        = string
  description = <<-EOT
    GCP project for a bucket created by this module. Always pass this explicitly rather than
    relying on the google provider's default project.
  EOT
}

variable "force_destroy" {
  type        = bool
  description = <<-EOT
    If true, a bucket created by this module can be destroyed even when it contains objects.
    Defaults to false so customer data is not deleted by accident. CI should set this true.
  EOT
  default     = false
}

variable "enable_versioning" {
  type        = bool
  description = <<-EOT
    Whether to enable object versioning on a bucket created by this module. Defaults to true.
    Set false only if you manage versioning outside this module.
  EOT
  default     = true
}

variable "bucket_access_logs_destination" {
  type        = string
  description = <<-EOT
    Existing GCS bucket that should receive access logs for a bucket this module creates.
    Recommended for production. If null, access logging is not configured.

    Prerequisite (this module does not grant it): the destination must allow
    `group:cloud-storage-analytics@google.com` to create objects
    (`roles/storage.objectCreator`, or equivalent). Without that, apply can succeed while no
    logs are written.
  EOT
  default     = null
  nullable    = true
}

variable "kms_crypto_key_name" {
  type        = string
  description = <<-EOT
    Optional CMEK for a bucket created by this module. Full CryptoKey resource name, e.g.
    `projects/my-project/locations/us/keyRings/import/cryptoKeys/gcs`. If null, Google-managed
    encryption is used. The key must be in the same location as the bucket.

    Prerequisite (this module does not grant it): the Cloud Storage service agent of the
    bucket's project must have `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key.
    Without that, apply fails when setting default encryption.
  EOT
  default     = null
  nullable    = true
}

variable "bucket_iam_role" {
  type        = string
  description = <<-EOT
    IAM role to grant the Worklytics tenant service account on each import bucket (read path).
    Defaults to roles/storage.objectViewer.

    Minimum permissions required to ingest:
      - storage.objects.get
      - storage.objects.list
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

variable "worklytics_host" {
  type        = string
  description = <<-EOT
    Hostname of the Worklytics instance (no scheme or path). Defaults to `app.worklytics.co`.
    Connection TODO URLs are built from this host.
  EOT
  default     = "app.worklytics.co"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$", var.worklytics_host))
    error_message = "`worklytics_host` must be a hostname without scheme or path (e.g. app.worklytics.co)."
  }
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

variable "todo_file_path" {
  type        = string
  description = <<-EOT
    Path for the local TODO file when `todos_as_local_files` is true. Set a unique path per
    module instance if several instances share one root module (they would otherwise overwrite
    the same file).
  EOT
  default     = "TODO - configure import in worklytics.md"
}
