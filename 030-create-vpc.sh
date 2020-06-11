#!/bin/bash
set -e
source ./shared.sh

# Use schematics to create a vpc environment

echo '>>> creating schematics.json from schematics.template.json'
jq -n --arg TF_VAR_basename $TF_VAR_basename --arg TF_VAR_ssh_key_name $TF_VAR_ssh_key_name "$(cat schematics.template.json)" > schematics.json

if workspace_id=$(get_workspace_id); then
  echo workspace $TF_VAR_basename already exists updating
  ibmcloud schematics workspace update --id $workspace_id --file schematics.json
  sleep 2
else
  ibmcloud schematics workspace new --file schematics.json
  workspace_id=$(get_workspace_id)
fi
poll_for_latest_action_to_finish $workspace_id

echo basename = "\"$TF_VAR_basename\"" > schematics.tfvars
echo ssh_key_name = "\"$TF_VAR_ssh_key_name\"" >> schematics.tfvars

echo '>>> terraform apply'
ibmcloud schematics apply --id $workspace_id --var-file schematics.tfvars -f --output json
poll_for_latest_action_to_finish $workspace_id

echo '>>> get vpc id'
vpc_id=$(ibmcloud schematics workspace output --id $workspace_id --json | jq -r '.[0].output_values[0]|.vpc_id.value')

# ( cd tf; terraform init; terraform apply -auto-approve )
# vpc_id=$(terraform output -state=tf/terraform.tfstate vpc_id)
ibmcloud is flow-log-create --bucket $COS_BUCKET_NAME --target $vpc_id --name $PREFIX-flowlog
