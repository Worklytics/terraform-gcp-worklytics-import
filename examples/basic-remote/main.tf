# example of consuming this module from the Terraform Registry once published

module "worklytics-import" {
  source  = "Worklytics/worklytics-import/gcp"
  version = "~> 0.1.0"

  # email of your Worklytics Tenant SA (obtain from the Worklytics app)
  worklytics_tenant_sa_email = "YOUR_SA_EMAIL@YOUR_PROJECT_ID.iam.gserviceaccount.com"

  # omit bucket_name to create a bucket in the provider project
  # bucket_name = "my-existing-bucket"
}
