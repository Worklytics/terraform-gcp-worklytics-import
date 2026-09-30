output "bucket_name" {
  value       = local.primary_import.bucket_name
  description = "Name of the primary GCS bucket used as the import landing zone."
}

output "bucket_url" {
  value       = "gs://${local.primary_import.bucket_name}"
  description = "gs:// URL of the primary import bucket."
}

output "import_buckets" {
  value       = local.resolved_import_targets
  description = <<-EOT
    Map of all import landing zones. A created bucket is keyed `primary`; existing
    `existing_buckets_to_import` entries are keyed `bucket:<name>`. Each value has
    `bucket_name` and whether the module created it.
  EOT
}

output "todo_markdown" {
  value       = var.todos_as_outputs ? local.todo_content : null
  description = "Actions that must be performed outside of Terraform (markdown format)."
}
