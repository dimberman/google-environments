module "astronomer_cloud" {

  source  = "astronomer/astronomer-cloud/google"
  version = "0.1.1141"

  deployment_id          = var.deployment_id
  email                  = "steven@astronomer.io"
  zonal_cluster          = false
  management_api         = "public"
  enable_gvisor          = false
  kubeconfig_path        = var.kubeconfig_path
  do_not_create_a_record = true
  lets_encrypt           = false
  base_domain            = var.base_domain

  tls_cert = data.http.fullchain.body
  tls_key  = data.http.privkey.body

  astronomer_chart_git_repository = "https://github.com/astronomer/astronomer.git"
  astronomer_version_git_checkout = "release-0.12"
  astronomer_version              = "0.12.0-alpha.2"

  astronomer_helm_values = local.helm_values

  worker_node_size      = local.worker_node_size
  max_worker_node_count = local.max_worker_node_count
  db_instance_size      = local.db_instance_size
}
