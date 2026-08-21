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

variable "bucket_name" {
  type        = string
  description = <<-EOT
    Existing GCS bucket for the primary import landing zone. If null and this module is managing
    a primary zone, a bucket is created. Providing a name skips primary bucket creation; the
    module only grants Worklytics read access.
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
    Optional additional existing GCS buckets to grant Worklytics read access to. Use this when
    the customer has several ingest locations. Names must refer to buckets that already exist.

    The singular `bucket_name` still describes the primary zone. A primary zone is managed when
    `bucket_name` is set *or* when this list is empty (the default create-one-bucket path). If
    this list is non-empty and `bucket_name` is null, only the list is used — no extra bucket is
    created. The first list entry is the primary for outputs and connection URLs.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for name in var.import_buckets :
      can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Each import_buckets value must be a valid GCS bucket name."
  }

  validation {
    condition     = length(var.import_buckets) == length(distinct(var.import_buckets))
    error_message = "`import_buckets` must not contain duplicate names."
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

variable "project_id" {
  type        = string
  description = <<-EOT
    GCP project in which to create a bucket. If null, the google provider's project is used.
    Set this when the provider is authenticated as a SA in a different project than the bucket
    (for example CI WIF from a corp SA creating buckets in a sandbox project).
  EOT
  default     = null
  nullable    = true
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
    Optional CMEK (full CryptoKey resource name) for a bucket created by this module. If null,
    Google-managed encryption is used. The key must be in the same location as the bucket.

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

variable "todo_file_path" {
  type        = string
  description = <<-EOT
    Path for the local TODO file when `todos_as_local_files` is true. Set a unique path per
    module instance if several instances share one root module (they would otherwise overwrite
    the same file).
  EOT
  default     = "TODO - configure import in worklytics.md"
}
