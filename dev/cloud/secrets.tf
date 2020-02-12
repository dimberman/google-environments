#####
# Email (SMTP)
#####

data "google_storage_object_signed_url" "smtp_uri" {
  bucket = "dev-astronomer-secrets"
  path   = "smtp_uri.txt"
}

data "http" "smtp_uri" {
  url = data.google_storage_object_signed_url.smtp_uri.signed_url
}
