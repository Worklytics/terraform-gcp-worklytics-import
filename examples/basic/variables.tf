variable "project_id" {
  type        = string
  description = "GCP project for a bucket created by the module. If null, the google provider project is used."
  default     = null
}

variable "resource_name_prefix" {
  type        = string
  description = "Prefix to give to names of infra created by this module, where applicable."
  default     = "worklytics-import-"
}

variable "worklytics_tenant_sa_email" {
  type        = string
  description = "Email address of your Worklytics tenant's service account (obtain from Worklytics App)."
}

variable "worklytics_host" {
  type        = string
  description = "Worklytics hostname for connection URLs."
  default     = "app.worklytics.co"
}

variable "bucket_name" {
  type        = string
  description = "Existing GCS bucket to reuse. If null, the module creates one."
  default     = null
}

variable "import_buckets" {
  type        = list(string)
  description = "Optional additional existing import buckets."
  default     = []
}

variable "location" {
  type        = string
  description = "Location for a bucket created by this module."
  default     = "US"
}

variable "force_destroy" {
  type        = bool
  description = "Allow destroying a created bucket that still has objects."
  default     = false
}

variable "todos_as_local_files" {
  type        = bool
  description = "Whether to render TODOs as flat files."
  default     = true
}
