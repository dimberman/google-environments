module "astronomer_cloud" {

  source  = "astronomer/astronomer-cloud/google"
  version = "0.1.868"

  deployment_id                = var.deployment_id
  email                        = "steven@astronomer.io"
  zonal_cluster                = true
  management_api               = "public"
  enable_gvisor                = false
  enable_kubecost              = false
  kubeconfig_path              = var.kubeconfig_path
  do_not_create_a_record       = false
  lets_encrypt                 = true
  base_domain                  = var.base_domain
  dns_managed_zone             = "steven-zone"
  enable_velero                = false
  enable_knative               = true
  enable_gke_metered_billing   = true
  create_dynamic_pods_nodepool = true

  worker_node_size = local.worker_node_size
  db_instance_size = local.db_instance_size
  public_signups   = local.public_signups
}
