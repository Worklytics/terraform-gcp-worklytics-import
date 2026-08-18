# Functional unit tests. Mocked google provider; no cloud credentials required.
# Requires Terraform >= 1.7 (`mock_provider`).

mock_provider "google" {
  mock_resource "google_storage_bucket" {
    defaults = {
      name     = "worklytics-import-created"
      location = "US"
      id       = "worklytics-import-created"
      project  = "worklytics-import-test"
    }
  }

  mock_resource "google_storage_bucket_iam_member" {
    defaults = {
      id = "bucket/roles/storage.objectViewer/serviceAccount:tenant@test.iam.gserviceaccount.com"
    }
  }
}

variables {
  worklytics_tenant_sa_email = "tenant@test-project.iam.gserviceaccount.com"
  todos_as_local_files       = false
}

run "creates_bucket_when_omitted" {
  command = plan

  assert {
    condition     = length(google_storage_bucket.import) == 1
    error_message = "Expected a GCS bucket to be created when bucket_name is omitted."
  }

  assert {
    condition = alltrue([
      for m in google_storage_bucket_iam_member.worklytics :
      m.role == "roles/storage.objectViewer"
    ])
    error_message = "Worklytics must be granted roles/storage.objectViewer on the import bucket by default."
  }

  assert {
    condition = alltrue([
      for m in google_storage_bucket_iam_member.worklytics :
      m.member == "serviceAccount:${var.worklytics_tenant_sa_email}"
    ])
    error_message = "IAM member must be the Worklytics tenant service account."
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import : b.versioning[0].enabled == true
    ])
    error_message = "Created buckets should have versioning enabled by default."
  }
}

run "reuses_existing_bucket" {
  command = plan

  variables {
    bucket_name = "already-there-bucket"
  }

  assert {
    condition     = length(google_storage_bucket.import) == 0
    error_message = "Should not create a bucket when bucket_name is provided."
  }

  assert {
    condition     = output.bucket_name == "already-there-bucket"
    error_message = "Output bucket name should match the provided existing bucket."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 1
    error_message = "Should still grant IAM on the reused bucket."
  }
}

run "rejects_invalid_tenant_sa_email" {
  command = plan

  variables {
    worklytics_tenant_sa_email = "not-an-sa-email"
  }

  expect_failures = [
    var.worklytics_tenant_sa_email,
  ]
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "NOT_VALID"
  }

  expect_failures = [
    var.bucket_name,
  ]
}

run "grants_access_to_additional_import_buckets" {
  command = plan

  variables {
    bucket_name    = "already-there-bucket"
    import_buckets = ["second-ingest-bucket"]
  }

  assert {
    condition     = length(google_storage_bucket.import) == 0
    error_message = "Should not create a bucket when all import locations already exist."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 2
    error_message = "Primary plus additional import buckets should each get IAM."
  }

  assert {
    condition     = length(output.import_buckets) == 2
    error_message = "import_buckets output should include primary and the extra landing zone."
  }
}

run "list_only_skips_created_primary" {
  command = plan

  variables {
    import_buckets = ["only-from-list"]
  }

  assert {
    condition     = length(google_storage_bucket.import) == 0
    error_message = "List-only existing locations should not create a bucket."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 1
    error_message = "List-only should grant access to exactly the listed buckets."
  }

  assert {
    condition     = output.bucket_name == "only-from-list"
    error_message = "Primary outputs should fall back to the listed bucket."
  }
}

run "rejects_invalid_import_buckets_name" {
  command = plan

  variables {
    import_buckets = ["NOT_VALID"]
  }

  expect_failures = [
    var.import_buckets,
  ]
}

run "enable_export_grants_object_admin" {
  command = plan

  variables {
    bucket_name   = "already-there-bucket"
    enable_export = true
  }

  assert {
    condition = anytrue([
      for m in google_storage_bucket_iam_member.worklytics :
      m.role == "roles/storage.objectAdmin"
    ])
    error_message = "enable_export must grant roles/storage.objectAdmin."
  }

  assert {
    condition = anytrue([
      for m in google_storage_bucket_iam_member.worklytics :
      m.role == "roles/storage.objectViewer"
    ])
    error_message = "enable_export should keep the import read role as well."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 2
    error_message = "Import + export should produce two IAM bindings on one bucket."
  }
}

run "disables_versioning_when_requested" {
  command = plan

  variables {
    enable_versioning = false
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import : b.versioning[0].enabled == false
    ])
    error_message = "enable_versioning=false should turn object versioning off."
  }
}

run "sets_project_id_on_created_bucket" {
  command = plan

  variables {
    project_id = "other-project"
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import : b.project == "other-project"
    ])
    error_message = "Created buckets should land in var.project_id when it is set."
  }
}

run "enables_access_logs_when_destination_set" {
  command = plan

  variables {
    bucket_access_logs_destination = "already-there-logs"
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import :
      b.logging[0].log_bucket == "already-there-logs"
    ])
    error_message = "bucket_access_logs_destination should configure bucket logging."
  }
}

run "enables_cmek_when_key_provided" {
  command = plan

  variables {
    kms_crypto_key_name = "projects/p/locations/us/keyRings/r/cryptoKeys/k"
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import :
      b.encryption[0].default_kms_key_name == "projects/p/locations/us/keyRings/r/cryptoKeys/k"
    ])
    error_message = "kms_crypto_key_name should set default_kms_key_name on created buckets."
  }
}
