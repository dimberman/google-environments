#!/bin/bash

echo $GOOGLE_CREDENTIAL_FILE_CONTENT > /tmp/account.json

set -xe

ls /tmp | grep account

export GOOGLE_APPLICATION_CREDENTIALS='/tmp/account.json'
export TF_IN_AUTOMATION=true

terraform -v

terraform init

# TODO: add to CI image
apk add --update  python  curl  which  bash jq
curl -sSL https://sdk.cloud.google.com > /tmp/gcl
bash /tmp/gcl --install-dir=~/gcloud --disable-prompts > /dev/null 2>&1
PATH=$PATH:/root/gcloud/google-cloud-sdk/bin

# Set up gcloud CLI
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project $PROJECT

PLAN_FILE="tfplan"

# If the cluster already exists, then we need
# to set up some things in the local environment.
# The block below is executed except for on the first
# run of this environment.

# get list of clusters
CLUSTERS=$(gcloud container clusters list)
KUBECONFIG_VAR_LINE=""
if [ $CLUSTERS == *$DEPLOYMENT_ID-cluster* ]; then

  # whitelist our current IP for kube management API
  gcloud container clusters update $DEPLOYMENT_ID-cluster --enable-master-authorized-networks --master-authorized-networks="$(curl icanhazip.com)/32" --zone=us-east4
  
  # copy the kubeconfig from the terraform state
  terraform state pull | jq -r '.resources[] | select(.module == "module.astronomer_cloud") | select(.name == "kubeconfig") | .instances[0].attributes.content' > kubeconfig
  chmod 755 kubeconfig
  KUBECONFIG_VAR_LINE="-var 'kubeconfig_path=$(pwd)/kubeconfig'"
fi

# Do the plan step and quit
# if TF_PLAN is set
if [ $TF_PLAN ]; then

	echo "\n Deleting old Terraform plan file"
	gsutil rm gs://${STATE_BUCKET}/ci/$PLAN_FILE || echo "\n An old state file does not exist in state bucket, proceeding..."

	terraform plan \
	  -var "deployment_id=$DEPLOYMENT_ID" \
    $KUBECONFIG_VAR_LINE \
	  -lock=false \
	  -input=false \
	  -out=$PLAN_FILE

	gsutil cp $PLAN_FILE gs://${STATE_BUCKET}/ci/$PLAN_FILE
  echo "Plan file uploaded"
  exit 0

fi

# Only turn on auto-approve when specified.
# Do not target a plan file.
TF_AUTO_APPROVE_LINE=""
if [ $TF_AUTO_APPROVE ]; then
  TF_AUTO_APPROVE_LINE="--auto-approve"
  PLAN_FILE=""
fi

if [ $TF_DESTROY ]; then

  # delete everything from kube
  helm init --client-only
  helm del $(helm ls --all --short) --purge

  # this command is blocking
  kubectl delete namespace astronomer -wait=true

  # remove the stuff we just delete from kube from the tf state
  terraform state rm module.astronomer_cloud.module.astronomer
  terraform state rm module.astronomer_cloud.module.system_components

  # this resource should be ignored on destroy
  # remove it from the state to accomplish this
  terraform state rm module.astronomer_cloud.module.gcp.google_sql_user.airflow

  terraform destroy \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    $TF_AUTO_APPROVE_LINE \
    $PLAN_FILE

  exit 0
fi 

terraform apply \
  -var "deployment_id=$DEPLOYMENT_ID" \
  -lock=false \
  -input=false \
  $KUBECONFIG_VAR_LINE \
  $TF_AUTO_APPROVE_LINE \
  $PLAN_FILE
