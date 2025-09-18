#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

NEEDED_PERMISSION_LIST="apigee.deployments.list,apigee.deployments.get,apigee.proxyrevisions.list,apigee.proxyrevisions.get,apigee.proxyrevisions.delete"

check_and_maybe_create_role() {
  local role_name project
  role_name="$1"
  project="$2"
  printf "Checking for role %s...\n" "$role_name"
  echo "gcloud iam roles describe \"$role_name\""
  if gcloud iam roles describe "$role_name" --project="$project" --quiet >>/dev/null 2>&1; then
    printf "That role exists...\n"
  else
    printf "Creating role %s ...\n" "${role_name}"
    if gcloud iam roles create "$role_name" --project="${project}" \
      --title="Stale Proxy Revision Reaper" \
      --description="Can list/get/delete proxyrevisions, and list/get deployments" \
      --permissions="${NEEDED_PERMISSION_LIST}" \
      --stage=GA --quiet; then
      printf "The role has been created.\n\n"
    else
      printf "Failed to create the service account.\n\n"
      exit 1
    fi
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
