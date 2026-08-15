# Development / CI example only. Customers should copy from the root README or
# examples/basic-remote/ (Terraform Registry source), not this relative path.

module "worklytics_import" {
  # Relative source so CI tests *this* checkout. Published usage:
  #   source  = "Worklytics/worklytics-import/gcp"
  #   version = "~> 0.1.0"
  source = "../../"

  resource_name_prefix       = var.resource_name_prefix
  worklytics_tenant_sa_email = var.worklytics_tenant_sa_email
  bucket_name                = var.bucket_name
  import_buckets             = var.import_buckets
  location                   = var.location
  force_destroy              = var.force_destroy
  enable_export              = var.enable_export
  todos_as_local_files       = var.todos_as_local_files
}

output "bucket_name" {
  value = module.worklytics_import.bucket_name
}

output "bucket_url" {
  value = module.worklytics_import.bucket_url
}

output "import_buckets" {
  value = module.worklytics_import.import_buckets
}
