data "google_storage_bucket_object_content" "project_variables" {
  name   = "project_variables.json"
  bucket = "orviss-homemanagement-tfstate"
}

locals {
  artifact_registry_name = jsondecode(data.google_storage_bucket_object_content.project_variables.content).artifactRegistryName
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run Service Account"
}

output "artifact_registry_name" {
  value = local.artifact_registry_name
}

# module "cloud_run_service" {
#   source = "../modules/cloud_run_service"

#   artifact_registry_id = local.artifact_registry_name
#   region = var.region
#   service_name = "google_auth_service"
#   image_name = "google_auth_service"
#   service_account = google_service_account.cloud_run_sa.email
# }

