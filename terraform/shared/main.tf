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

resource "google_iam_workload_identity_pool" "gh_actions_pool" {
  workload_identity_pool_id = "gh-actions-pool"
  description               = null
  disabled                  = false
  display_name              = "Github Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "gh_actions_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_actions_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "gh-actions-provider"
  attribute_condition                = "assertion.repository_owner == 'prorviss'"
  attribute_mapping = {
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "google.subject"             = "assertion.sub"
  }
  description  = null
  disabled     = false
  display_name = "Github Actions Provider"

  oidc {
    allowed_audiences = []
    issuer_uri        = "https://token.actions.githubusercontent.com"
    jwks_json         = null
  }
}

resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-sa"
  description  = null
  disabled     = false
  display_name = "Terraform Service Account"
}

resource "google_project_iam_member" "terraform_sa_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

resource "google_project_iam_member" "terraform_sa_storage-admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

resource "google_project_iam_member" "terraform_sa_workload-identity-user" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}
