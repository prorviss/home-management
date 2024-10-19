locals {
  api_services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com"
  ]
  stateBucket = "orviss-homemanagement-tfstate"
  serviceAccount = {
    name         = "terraform-sa"
    display_name = "Terraform Service Account"
    project_roles = [
      "roles/resourcemanager.projectIamAdmin",
      "roles/editor",
      "roles/storage.admin",
      "roles/iam.workloadIdentityUser",
      "roles/run.admin"
    ]
  }
}