# example of consuming this module from the Terraform Registry once published

module "worklytics-import" {
  source  = "Worklytics/worklytics-import/gcp"
  version = "~> 0.1.0"

  project_id = "YOUR_GCP_PROJECT"

  # email of your Worklytics Tenant SA (obtain from the Worklytics app)
  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"

  # omit to create a bucket; set to grant access on existing buckets only
  # existing_buckets_to_import = ["my-existing-bucket"]
}
