terraform {
  required_version = ">= 0.12"
  backend "gcs" {
    bucket = "cloud2-dev-terraform"
    prefix = "devcluster/terraform.tfstate"
  }
}
