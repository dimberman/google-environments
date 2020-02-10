#!/bin/bash

cd $DIRECTORY

echo $GOOGLE_CREDENTIAL_FILE_CONTENT > /tmp/account.json

set -xe

ls /tmp | grep account

export GOOGLE_APPLICATION_CREDENTIALS='/tmp/account.json'
export TF_IN_AUTOMATION=true

terraform -v

terraform init

# TODO: add to CI image
apk add --update  python  curl  which  bash # jq
curl -sSL https://sdk.cloud.google.com > /tmp/gcl
bash /tmp/gcl --install-dir=~/gcloud --disable-prompts > /dev/null 2>&1
PATH=$PATH:/root/gcloud/google-cloud-sdk/bin

# Set up gcloud CLI
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project $PROJECT
gcloud components install beta -q

PLAN_FILE="tfplan"

# If the cluster already exists, then we need
# to set up some things in the local environment.
# The block below is executed except for on the first
# run of this environment.

export ORIGINAL_WHITELIST=""
function finish {
  # Remove ourselves from the whitelist
  if [[ "$ORIGINAL_WHITELIST" == "" ]]; then
    gcloud container clusters update $DEPLOYMENT_ID-cluster --enable-master-authorized-networks --region=us-east4
  else
    gcloud container clusters update $DEPLOYMENT_ID-cluster --enable-master-authorized-networks --master-authorized-networks="${ORIGINAL_WHITELIST}" --region=us-east4
  fi
}
trap finish EXIT
# get list of clusters
CLUSTERS="$(gcloud container clusters list --format="value(name)" | tr '\r\n' ' ')"
KUBECONFIG_VAR_LINE=""
if [[ "$CLUSTERS" == *$DEPLOYMENT_ID-cluster* ]]; then

  export ORIGINAL_WHITELIST="$(gcloud beta container clusters describe $DEPLOYMENT_ID-cluster --region=us-east4  --format="value(masterAuthorizedNetworksConfig.cidrBlocks[].cidrBlock.list())")"
  # Replace whitelist with our IP
  gcloud container clusters update $DEPLOYMENT_ID-cluster --enable-master-authorized-networks --master-authorized-networks="$(curl -4 icanhazip.com)/32" --region=us-east4

  export KUBECONFIG=$(pwd)/kubeconfig
  # copy the kubeconfig from the terraform state
  # terraform state pull | jq -r '.resources[] | select(.module == "module.astronomer_cloud") | select(.name == "kubeconfig") | .instances[0].attributes.content' > kubeconfig
  gcloud beta container clusters get-credentials $DEPLOYMENT_ID-cluster --region us-east4 --project $PROJECT
  chmod 755 kubeconfig
  KUBECONFIG_VAR_LINE="-var kubeconfig_path=$(pwd)/kubeconfig"

  mkdir -p ~/.kube/
  cp $KUBECONFIG ~/.kube/config
  curl -Lo /tmp/tiller-releases-converter https://github.com/dragonsmith/tiller-releases-converter/releases/download/0.1.2/tiller-releases-converter.linux.amd64
  chmod +x /tmp/tiller-releases-converter
  /tmp/tiller-releases-converter convert
  /tmp/tiller-releases-converter secure-tiller

fi

helm repo update

if [ $TF_FORCE_REDEPLOY ]; then

  if [ ! $TF_AUTO_APPROVE ]; then
    echo "ERROR: will not destroy without TF_AUTO_APPROVE set"
    exit 1
  fi

  helm init --client-only

  # make sure infra is up to date
  terraform apply \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    --auto-approve \
    --target=module.astronomer_cloud.module.gcp

  # delete helm charts
  terraform state rm module.astronomer_cloud.module.astronomer.helm_release.astronomer
  terraform state rm module.astronomer_cloud.module.system_components.helm_release.cloud_sql_proxy
  terraform state rm module.astronomer_cloud.module.system_components.helm_release.istio
  terraform state rm module.astronomer_cloud.module.system_components.helm_release.istio_init
  terraform state rm module.astronomer_cloud.module.system_components.null_resource.helm_repo
  helm delete --purge astronomer istio istio-init pg-sqlproxy || true

  # reapply kube layer, making sure to do system components first

  terraform apply \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    --target=module.astronomer_cloud.module.system_components \
    --auto-approve

  terraform apply \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    --auto-approve

  exit 0
fi

if [ $TF_DESTROY ]; then

  if [ ! $TF_AUTO_APPROVE ]; then
    echo "ERROR: will not destroy without TF_AUTO_APPROVE set"
    exit 1
  fi

  # don't fail if one of these fails
  set +e

  # delete everything from kube
  helm init --client-only
  helm del $(helm ls --all --short) --purge

  # this command is blocking
  kubectl delete namespace astronomer --wait=true

  # remove the stuff we just delete from kube from the tf state
  terraform state rm module.astronomer_cloud.module.astronomer
  terraform state rm module.astronomer_cloud.module.system_components

  # this resource should be ignored on destroy
  # remove it from the state to accomplish this
  terraform state rm module.astronomer_cloud.module.gcp.google_sql_user.airflow

  # resume normal failure
  set -e

  terraform destroy \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    -refresh=false \
    $KUBECONFIG_VAR_LINE \
    --auto-approve

  exit 0
fi

if [ $TF_TWO_STEP_APPLY ]; then

  if [ ! $TF_AUTO_APPROVE ]; then
    echo "ERROR: will not two step apply without TF_AUTO_APPROVE set"
    exit 1
  fi

  terraform apply \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    --auto-approve \
    --target=module.astronomer_cloud.module.gcp

  terraform apply \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    -lock=false \
    -input=false \
    $KUBECONFIG_VAR_LINE \
    --auto-approve

  exit 0
fi

STATE_BUCKET="astronomer-$DEPLOYMENT_ID-terraform-state"
# Do the plan step and quit
# if TF_PLAN is set.
# Otherwise, proceed to the apply step
if [ $TF_PLAN ]; then

	echo "\n Deleting old Terraform plan file"
	gsutil rm gs://${STATE_BUCKET}/ci/$PLAN_FILE || echo "\n An old state file does not exist in state bucket, proceeding..."
	gsutil rm gs://${STATE_BUCKET}/ci/$PLAN_FILE-infra-only || echo "\n An old state file does not exist in state bucket, proceeding..."

  terraform plan \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    $KUBECONFIG_VAR_LINE \
    -lock=false \
    -input=false \
    --target=module.astronomer_cloud.module.gcp \
    -out=$PLAN_FILE-infra-only

	gsutil cp $PLAN_FILE-infra-only gs://${STATE_BUCKET}/ci/$PLAN_FILE-infra-only
  echo "Plan file uploaded - infra only"

  echo "############################"
  echo "############################"

  terraform plan \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    $KUBECONFIG_VAR_LINE \
    -lock=false \
    -input=false \
    -out=$PLAN_FILE

	gsutil cp $PLAN_FILE gs://${STATE_BUCKET}/ci/$PLAN_FILE
  echo "Plan file uploaded"

  exit 0

fi

if [ $TF_AUTO_APPROVE ]; then

  terraform plan \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    $KUBECONFIG_VAR_LINE \
    -lock=false \
    -input=false \
    -out=$PLAN_FILE

  # temporarily, we will disable deploying
  # so I can avoid messing up staging.
  exit 0

  terraform apply \
    -lock=false \
    -refresh=false \
    -input=false \
    $PLAN_FILE

  /tmp/tiller-releases-converter cleanup
  rm ~/.kube/config

  exit 0
fi

if [ $TF_INFRA_ONLY ]; then

  # apply using plan file
  gsutil cp gs://${STATE_BUCKET}/ci/$PLAN_FILE-infra-only $PLAN_FILE-infra-only
  terraform apply \
    -lock=false \
    -refresh=false \
    -input=false \
    $PLAN_FILE-infra-only

  # delete both plan files because they are now expired
  gsutil rm gs://${STATE_BUCKET}/ci/$PLAN_FILE-infra-only || echo "\n An old state file does not exist in state bucket, proceeding..."
  gsutil rm gs://${STATE_BUCKET}/ci/$PLAN_FILE || echo "\n An old state file does not exist in state bucket, proceeding..."

  # re-plan
  terraform plan \
    -var "deployment_id=$DEPLOYMENT_ID" \
    -var "base_domain=$BASE_DOMAIN" \
    $KUBECONFIG_VAR_LINE \
    -lock=false \
    -input=false \
    -out=$PLAN_FILE

  gsutil cp $PLAN_FILE gs://${STATE_BUCKET}/ci/$PLAN_FILE
  echo "Plan file uploaded"

  exit 0
fi

# apply using plan file
gsutil cp gs://${STATE_BUCKET}/ci/$PLAN_FILE $PLAN_FILE
terraform apply \
  -lock=false \
  -refresh=false \
  -input=false \
  $PLAN_FILE

/tmp/tiller-releases-converter cleanup
rm ~/.kube/config
