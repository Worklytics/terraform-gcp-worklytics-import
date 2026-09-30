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
  project_id                 = "worklytics-import-test"
  worklytics_tenant_sa_email = "tenant@test-project.iam.gserviceaccount.com"
  todos_as_local_files       = false
}

run "creates_bucket_when_list_empty" {
  command = plan

  assert {
    condition     = length(google_storage_bucket.import) == 1
    error_message = "Expected a GCS bucket to be created when existing_buckets_to_import is empty."
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

run "reuses_existing_buckets" {
  command = plan

  variables {
    existing_buckets_to_import = ["already-there-bucket"]
  }

  assert {
    condition     = length(google_storage_bucket.import) == 0
    error_message = "Should not create a bucket when existing_buckets_to_import is set."
  }

  assert {
    condition     = output.bucket_name == "already-there-bucket"
    error_message = "Output bucket name should match the first existing bucket."
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

run "grants_access_to_each_existing_bucket" {
  command = plan

  variables {
    existing_buckets_to_import = ["already-there-bucket", "second-ingest-bucket"]
  }

  assert {
    condition     = length(google_storage_bucket.import) == 0
    error_message = "Should not create a bucket when existing locations are listed."
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 2
    error_message = "Each existing import bucket should get IAM."
  }

  assert {
    condition     = length(output.import_buckets) == 2
    error_message = "import_buckets output should include every listed landing zone."
  }
}

run "rejects_invalid_resource_name_prefix" {
  command = plan

  variables {
    resource_name_prefix = "-not-a-valid-gcs-prefix"
  }

  expect_failures = [
    var.resource_name_prefix,
  ]
}

run "existing_list_preserves_first_bucket_as_primary" {
  command = plan

  variables {
    existing_buckets_to_import = ["zebra-ingest-bucket", "alpha-ingest-bucket"]
  }

  assert {
    condition     = output.bucket_name == "zebra-ingest-bucket"
    error_message = "Primary outputs should follow caller order, not lexicographic sort."
  }
}

run "bucket_named_primary_does_not_collide" {
  command = plan

  variables {
    existing_buckets_to_import = ["already-there-bucket", "primary"]
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.worklytics) == 2
    error_message = "A listed bucket named primary must not collide with the reserved primary key."
  }

  assert {
    condition     = output.bucket_name == "already-there-bucket"
    error_message = "The first listed bucket remains the primary landing zone."
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

run "created_bucket_uses_project_id" {
  command = plan

  variables {
    project_id = "other-project"
  }

  assert {
    condition = alltrue([
      for b in google_storage_bucket.import : b.project == "other-project"
    ])
    error_message = "Created buckets should land in var.project_id."
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

run "todo_urls_use_worklytics_host" {
  command = plan

  variables {
    existing_buckets_to_import = ["already-there-bucket"]
    todos_as_outputs           = true
    worklytics_host            = "acme.worklytics.co"
  }

  assert {
    condition     = strcontains(output.todo_markdown, "https://acme.worklytics.co/analytics/connect/gcs-import?bucket=already-there-bucket")
    error_message = "TODO deep links must use worklytics_host."
  }
}

run "rejects_worklytics_host_with_scheme" {
  command = plan

  variables {
    worklytics_host = "https://app.worklytics.co"
  }

  expect_failures = [
    var.worklytics_host,
  ]
}
