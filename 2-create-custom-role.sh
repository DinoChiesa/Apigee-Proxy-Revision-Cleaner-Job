#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

NEEDED_PERMISSIONS=("apigee.deployments.list"
  "apigee.deployments.get"
  "apigee.proxies.list"
  "apigee.proxies.get"
  "apigee.proxyrevisions.list"
  "apigee.proxyrevisions.get"
  "apigee.proxyrevisions.delete"
  "apigee.sharedflowrevisions.list"
  "apigee.sharedflows.get"
  "apigee.sharedflows.list"
  "apigee.sharedflowrevisions.get"
  "apigee.sharedflowrevisions.delete")

check_and_maybe_create_role() {
  local role_name project permissions_list
  role_name="$1"
  project="$2"
  printf "Checking for role %s...\n" "$role_name"
  echo "gcloud iam roles list... \"$role_name\""
  if [[ -z "$(gcloud iam roles list \
    --project="$project" \
    --filter="name:$role_name AND NOT deleted:true" \
    --format="value(name)" 2>/dev/null)" ]]; then
    printf "Creating role %s ...\n" "${role_name}"
    permissions_list=$(
      IFS=","
      echo "${NEEDED_PERMISSIONS[*]}"
    )
    if gcloud iam roles create "$role_name" --project="${project}" \
      --title="Apigee Revision Reaper" \
      --description="Can list/get/delete revisions of proxies and sharedflows, and list/get deployments" \
      --permissions="${permissions_list}" \
      --stage=GA --quiet; then
      printf "The role has been created.\n\n"
    else
      printf "Failed to create the role.\n\n"
      exit 1
    fi
  else
    printf "That role exists...\n"
  fi
}

# ====================================================================

check_shell_variables APIGEE_PROJECT_ID CUSTOM_ROLE_ID
check_required_commands gcloud

printf "\nThis script creates a custom IAM Role.\n"
printf "It will be used by the service account the Revision Cleaner Job will run as.\n"

printf "Creating a custom role '%s' in project %s...\n" "$CUSTOM_ROLE_ID" "$APIGEE_PROJECT_ID"
check_and_maybe_create_role "$CUSTOM_ROLE_ID" "$APIGEE_PROJECT_ID"

printf "\nOK.\n\n"
