provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "storage" {
  name     = "orviss-homemanagement-tfstate"
  location = var.region

  soft_delete_policy {
    retention_duration_seconds = 604800
  }

  versioning {
    enabled = true
  }
}
