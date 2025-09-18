#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

set -e

source ./lib/utils.sh

# ====================================================================

check_shell_variables CLOUDRUN_PROJECT_ID JOB_NAME JOB_REGION JOB_SERVICE_ACCOUNT REVISIONS_TO_KEEP APIGEE_PROJECT_ID
check_required_commands gcloud

printf "\nThis script creates the Revision Cleaner Job.\n"

SA_EMAIL="${JOB_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
printf "For the job, the Service Account email is:\n  %s\n" "$SA_EMAIL"

gcloud run jobs deploy "${JOB_NAME}" \
    --source . \
    --tasks 1 \
    --set-env-vars CMDARGS="-o ${APIGEE_PROJECT_ID} -K ${REVISIONS_TO_KEEP} --magictoken --apigeex -v" \
    --max-retries 1 \
    --region "${JOB_REGION}" \
    --project="${CLOUDRUN_PROJECT_ID}" \
    --service-account "${SA_EMAIL}"

printf "\nOK.\n\n"
printf "To execute the job, _right now_, you can use:\n\n"
printf "   gcloud run jobs execute ${JOB_NAME} --project=\"\${CLOUDRUN_PROJECT_ID}\"\n\n"
