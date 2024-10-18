variable "region" {
  description = "Google Cloud region"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
}

variable "artifact_registry_id" {
  description = "Artificat Registry Id"
  type        = string
}

variable "image_name" {
  description = "Container image in the Artifact Registry"
  type        = string
}

variable "service_account" {
  description = "The service account for the Cloud Run service"
}

variable "cpu_limit" {
  description = "CPU Core Limit"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory Limit"
  type        = string
  default     = "512Mi"
}