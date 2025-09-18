#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

SA_REQUIRED_ROLES=("roles/run.invoker")

maybe_add_role() {
  local sa_email project job_name region role user_member
  sa_email="$1"
  project="$2"
  job_name="$3"
  region="$4"
  role="$5"
  user_member="serviceAccount:${sa_email}"

  printf "Checking for existing binding for %s on %s..." "${user_member}" "${project}"
  existing_binding=$(cloud run jobs get-iam-policy "${JOB_NAME}" --region "${JOB_REGION}" \
    --project="$project" \
    --filter="bindings.role = '${role}' AND bindings.members = '${user_member}'" \
    --format="value(bindings.role)" \
    2>/dev/null)

  # Check if the command output an empty string
  if [[ -n "${existing_binding}" ]]; then
    printf "Binding already exists. No action needed.\n"
  else
    printf "adding binding to Cloud Run Job....\n"
    gcloud run jobs add-iam-policy-binding "$job_name" --project="${project}" \
      --region="$region" --member "${user_member}" --role "${role}" --condition=None
  fi
}

# ====================================================================

check_shell_variables CLOUDRUN_PROJECT_ID SCHEDULER_SERVICE_ACCOUNT SCHEDULER_JOB_NAME JOB_NAME JOB_REGION
check_required_commands gcloud

printf "\nThis script creates the scheduler for the Revision Cleaner Job.\n"

check_and_maybe_create_sa "$SCHEDULER_SERVICE_ACCOUNT" "$CLOUDRUN_PROJECT_ID"

SA_EMAIL="${SCHEDULER_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
printf "For the scheduler, the Service Account email is:\n  %s\n" "$SA_EMAIL"

printf "The scheduler Service Account needs run invoker on that Cloud Run Job\n"
maybe_add_role "$SA_EMAIL" "$CLOUDRUN_PROJECT_ID" "${JOB_NAME}" "$JOB_REGION" "roles/run.invoker"

printf "\nOK.\n\n"
