data "google_storage_bucket_object_content" "project_variables" {
  name   = "project_variables.json"
  bucket = "orviss-homemanagement-tfstate"
}

locals {
  artifact_registry_name = jsondecode(data.google_storage_bucket_object_content.project_variables.content).artifactRegistryName
}

data "google_artifact_registry_docker_image" "container_image" {
  location      = var.region
  repository_id = local.artifact_registry_name
  image_name    = "google-auth-service"
}

data "google_service_account" "cloud_run_sa" {
  project    = var.project_id
  account_id = "cloudrun-sa"
}

resource "google_cloud_run_v2_service" "cloud_run_service" {
  name                = "google-auth-service"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = data.google_service_account.cloud_run_sa.email

    containers {
      image = data.google_artifact_registry_docker_image.container_image.self_link

      env {
        name  = "GOOGLE_PROJECT_ID"
        value = var.project_id
      }

      env {
        name = "GOOGLE_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = "HOME_MANAGEMENT_CLIENT_ID"
            version = "1"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = "HOME_MANAGEMENT_CLIENT_SECRET"
            version = "1"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_binding" "binding" {
  location = var.region
  name     = google_cloud_run_v2_service.cloud_run_service.name
  role     = "roles/run.invoker"
  members = [
    "allUsers",
    "serviceAccount:${data.google_service_account.cloud_run_sa.email}"
  ]
}


