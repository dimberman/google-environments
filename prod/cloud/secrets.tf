#####
# TLS
#####

data "google_storage_object_signed_url" "fullchain" {
  bucket = "${var.deployment_id}-astronomer-certificate"
  path   = "fullchain3.pem"
}

data "google_storage_object_signed_url" "privkey" {
  bucket = "${var.deployment_id}-astronomer-certificate"
  path   = "privkey3.pem"
}

# for this to work, the content type in the metadata on the
# bucket objects must be "text/plain; charset=utf-8"
data "http" "fullchain" {
  url = data.google_storage_object_signed_url.fullchain.signed_url
}

data "http" "privkey" {
  url = data.google_storage_object_signed_url.privkey.signed_url
}

#####
# Stripe
#####

data "google_storage_object_signed_url" "stripe_pk" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "stripe_pk.txt"
}

data "google_storage_object_signed_url" "stripe_secret_key" {
  bucket = "${var.deployment_id}-astronomer-secrets"
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

#####
# Slack
#####

data "google_storage_object_signed_url" "slack_alert_url" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "slack_alert_url.txt"
}

data "http" "slack_alert_url" {
  url = data.google_storage_object_signed_url.slack_alert_url.signed_url
}

data "google_storage_object_signed_url" "slack_alert_url_platform" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "slack_alert_url_platform.txt"
}

data "http" "slack_alert_url_platform" {
  url = data.google_storage_object_signed_url.slack_alert_url_platform.signed_url
}
#####
# Email (SMTP)
#####

data "google_storage_object_signed_url" "smtp_uri" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "smtp_uri.txt"
}

data "http" "smtp_uri" {
  url = data.google_storage_object_signed_url.smtp_uri.signed_url
}

#####
# Kubecost Token
#####

data "google_storage_object_signed_url" "kubecost_token" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "kubecost_token.txt"
}

data "http" "kubecost_token" {
  url = data.google_storage_object_signed_url.kubecost_token.signed_url
}

#####
# Pager Duty
#####

data "google_storage_object_signed_url" "pagerduty_service_key" {
  bucket = "${var.deployment_id}-astronomer-secrets"
  path   = "pagerduty_service_key.txt"
}

data "http" "pagerduty_service_key" {
  url = data.google_storage_object_signed_url.pagerduty_service_key.signed_url
}
