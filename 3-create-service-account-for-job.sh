#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

# a space separated string
SA_REQUIRED_ROLES="projects/${APIGEE_PROJECT_ID}/roles/${CUSTOM_ROLE_ID}"

maybe_add_iam_binding_on_sa() {
  local user_member sa_email role project
  user_member="user:$1"
  sa_email="$2"
  project="$3"
  role="$4"

  printf "Checking for existing binding for %s on %s...\n" "${user_member}" "${sa_email}"
  # Fetch the policy and filter for the specific binding.
  # --filter checks for a binding with *both* the role AND the member.
  # --format="value(bindings.role)" prints the role string if found, or an empty string if not.

  existing_binding=$(gcloud iam service-accounts get-iam-policy "${sa_email}" \
    --project="${project}" \
    --filter="bindings.role = '${role}' AND bindings.members = '${user_member}'" \
    --format="value(bindings.role)" \
    2>/dev/null) # Suppress stderr in case of no policy, etc.

  # Check if the command output an empty string
  if [[ -n "${existing_binding}" ]]; then
    printf "Binding already exists. No action needed.\n"
  else
    printf "adding serviceAccountUser to self, to allow creation of the cloud run job with this SA.\n"
    gcloud iam service-accounts add-iam-policy-binding "${sa_email}" \
      --project="${project}" --member "${user_member}" --role "${role}"
  fi
}

# ====================================================================

check_shell_variables CLOUDRUN_PROJECT_ID APIGEE_PROJECT_ID JOB_SERVICE_ACCOUNT CUSTOM_ROLE_ID
check_required_commands gcloud

printf "\nThis script creates the service account the Revision Cleaner Job will run as.\n"

check_and_maybe_create_sa "$JOB_SERVICE_ACCOUNT" "$CLOUDRUN_PROJECT_ID"
apply_roles_to_sa "$JOB_SERVICE_ACCOUNT" "$CLOUDRUN_PROJECT_ID" "$APIGEE_PROJECT_ID" "$SA_REQUIRED_ROLES"

SA_EMAIL="${JOB_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
printf "For the job, the Service Account email is:\n  %s\n" "$SA_EMAIL"

gwhoami=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
maybe_add_iam_binding_on_sa "$gwhoami" "$SA_EMAIL" "$CLOUDRUN_PROJECT_ID" "roles/iam.serviceAccountUser"

printf "\nOK.\n\n"
