module "astronomer_cloud" {

  source  = "astronomer/astronomer-cloud/google"
  version = "0.1.624"

  deployment_id          = var.deployment_id
  email                  = "steven@astronomer.io"
  zonal_cluster          = false
  management_api         = "public"
  enable_gvisor          = false
  enable_kubecost        = true
  kubeconfig_path        = var.kubeconfig_path
  do_not_create_a_record = true
  lets_encrypt           = false
  base_domain            = var.base_domain

  tls_cert              = data.http.fullchain.body
  tls_key               = data.http.privkey.body
  stripe_secret_key     = data.http.stripe_secret_key.body
  stripe_pk             = data.http.stripe_pk.body
  smtp_uri              = data.http.smtp_uri.body
  slack_alert_url       = data.http.slack_alert_url.body
  kubecost_token        = data.http.kubecost_token.body
  pagerduty_service_key = data.http.pagerduty_service_key.body

  slack_alert_channel = var.slack_alert_channel

  worker_node_size = local.worker_node_size
  db_instance_size = local.db_instance_size
  public_signups   = local.public_signups
}
