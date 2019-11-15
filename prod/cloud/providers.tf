provider "google" {
  version = "~> 2.20"
  region  = "us-east4"
  zone    = "us-east4-a"
  project = "astronomer-cloud-prod"
}

provider "google-beta" {
  version = "~> 2.20"
  region  = "us-east4"
  zone    = "us-east4-a"
  project = "astronomer-cloud-prod"
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
  version    = "~> 1.4"
}

provider "http" {
  version = "~> 1.1"
}

provider "local" {
  version = "~> 1.3"
}

provider "null" {
  version = "~> 2.1"
}

provider "random" {
  version = "~> 2.2"
}

provider "tls" {
  version = "~> 2.1"
}
