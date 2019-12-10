variable "deployment_id" {}

variable "base_domain" {}

variable "kubeconfig_path" {
  default = ""
  type    = string
}

variable "slack_alert_channel" {
  default = "cloud2-alerts-prod"
  type    = string
}

variable "slack_alert_channel_platform" {
  default = "cloud2-alerts-prod-platform"
  type    = string
}
