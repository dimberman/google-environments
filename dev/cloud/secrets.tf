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

#####
# Stripe
#####

data "google_storage_object_signed_url" "stripe_pk" {
  bucket = "dev-astronomer-secrets"
  path   = "stripe_pk.txt"
}

data "google_storage_object_signed_url" "stripe_secret_key" {
  bucket = "dev-astronomer-secrets"
  path   = "stripe_secret_key.txt"
}

# for this to work, the content type in the metadata on the
# bucket objects must be "text/plain; charset=utf-8"
data "http" "stripe_pk" {
  url = data.google_storage_object_signed_url.stripe_pk.signed_url
}

data "http" "stripe_secret_key" {
  url = data.google_storage_object_signed_url.stripe_secret_key.signed_url
}
