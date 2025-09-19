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

  printf "Checking for existing binding for %s on %s...\n" "${user_member}" "${project}"
  existing_binding=$(gcloud run jobs get-iam-policy "${JOB_NAME}" --region "${JOB_REGION}" \
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
      --region="$region" --member "${user_member}" --role "${role}"
  fi
}

maybe_create_sched_job() {
  local sched_job_name project region schedule tz job_name sa_email uri
  sched_job_name="$1"
  project="$2"
  region="$3"
  schedule="$4"
  tz="$5"
  job_name="$6"
  sa_email="$7"

  # This is the kickoff URI for the Cloud Run Job
  uri="https://${region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${project}/jobs/${job_name}:run"

  printf "Checking for existing scheduler job %s...\n" "${sched_job_name}"
  if ! gcloud scheduler jobs describe "${sched_job_name}" \
    --location "${region}" \
    --project "${project}" \
    --quiet >/dev/null 2>&1; then

    printf "Creating a scheduler job %s...\n" "${sched_job_name}"
    gcloud scheduler jobs create http "${sched_job_name}" \
      --project "${project}" \
      --location "${region}" \
      --schedule "${schedule}" \
      --time-zone "${tz}" \
      --uri "$uri" \
      --http-method POST \
      --oauth-service-account-email "${sa_email}"
  else
    printf "A scheduler job by that name already exists.\n"
  fi
}

# ====================================================================

check_shell_variables CLOUDRUN_PROJECT_ID SCHEDULER_SERVICE_ACCOUNT SCHEDULER_JOB_NAME \
  JOB_NAME JOB_REGION SCHEDULE_TZ SCHEDULE
check_required_commands gcloud

printf "\nThis script creates the scheduler for the Revision Cleaner Job.\n"

check_and_maybe_create_sa "$SCHEDULER_SERVICE_ACCOUNT" "$CLOUDRUN_PROJECT_ID"

SA_EMAIL="${SCHEDULER_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
printf "For the scheduler, the Service Account email is:\n  %s\n" "$SA_EMAIL"

printf "The scheduler Service Account needs run invoker on that Cloud Run Job\n"
maybe_add_role "$SA_EMAIL" "$CLOUDRUN_PROJECT_ID" "${JOB_NAME}" "$JOB_REGION" "roles/run.invoker"

printf "Checking and maybe Creating the scheduler job...\n"
maybe_create_sched_job \
  "${SCHEDULER_JOB_NAME}" \
  "${CLOUDRUN_PROJECT_ID}" \
  "${JOB_REGION}" \
  "${SCHEDULE}" \
  "${SCHEDULE_TZ}" \
  "${JOB_NAME}" \
  "${SA_EMAIL}"

printf "\nOK.\n\n"
