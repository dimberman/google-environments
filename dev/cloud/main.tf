module "astronomer_cloud" {

  source  = "astronomer/astronomer-cloud/google"
  version = "0.1.1119"

  deployment_id = "dev"
  email         = "steven@astronomer.io"
  # zonal is smaller than regional
  zonal_cluster          = true
  management_api         = "public"
  enable_gvisor          = false
  enable_kubecost        = false
  kubeconfig_path        = var.kubeconfig_path
  do_not_create_a_record = false
  lets_encrypt           = true
  enable_velero          = false

  kube_version_gke       = "1.14.10-gke.21"

  astronomer_helm_values = local.helm_values

  base_domain                  = "dev.steven-google-development.com"
  dns_managed_zone             = "steven-zone"
  create_dynamic_pods_nodepool = true

  worker_node_size = local.worker_node_size
  db_instance_size = local.db_instance_size
}
