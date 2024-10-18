data "google_artifact_registry_docker_image" "container_image" {
  location      = var.region
  repository_id = var.artifact_registry_id
  image_name    = var.image_name
}

resource "google_cloud_run_service" "cloud_run_service" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      containers {
        image = data.google_artifact_registry_docker_image.container_image.self_link

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
      }

      service_account_name = var.service_account
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_binding" "binding" {
  service  = google_cloud_run_service.cloud_run_service.name
  location = var.region
  role     = "roles/run.invoker"
  members = [
    "allUsers",
    var.service_account
  ]
}
