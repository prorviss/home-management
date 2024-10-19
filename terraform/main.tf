resource "google_project_service" "api_services" {
  for_each = toset(local.api_services)
  project  = var.project_id
  service  = each.key
}

resource "google_service_account" "terraform_sa" {
  account_id   = local.serviceAccount.name
  display_name = local.serviceAccount.display_name
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloudrun-sa"
  display_name = "Cloud Run Service Account"
}

resource "google_project_iam_member" "cloud_run_sa_roles" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "service_account_roles" {
  for_each = toset(local.serviceAccount.project_roles)
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.terraform_sa.email}"
}

resource "google_storage_bucket" "storage" {
  name     = local.stateBucket
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

resource "google_artifact_registry_repository" "home-management-docker-registry" {
  location      = var.region
  repository_id = "home-management-docker-registry"
  description   = "Docker repository"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }
}

resource "google_storage_bucket_object" "project_variables" {
  name = "project_variables.json"
  content = jsonencode(
    {
      "projectId"            = var.project_id
      "projectNumber"        = var.project_number
      "region"               = var.region
      "artifactRegistryName" = google_artifact_registry_repository.home-management-docker-registry.name
      "artifactRegistryId"   = google_artifact_registry_repository.home-management-docker-registry.id
    }
  )
  bucket = google_storage_bucket.storage.name
}
