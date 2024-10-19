terraform {
  backend "gcs" {
    bucket = "orviss-homemanagement-tfstate"
    prefix = "terraform/state-services"
  }
}
