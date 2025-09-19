# The GCP project that will host the Cloud Run job
export CLOUDRUN_PROJECT_ID=my-gcp-project
# The GCP project that hosts Apigee. Maybe the same.
export APIGEE_PROJECT_ID=my-apigee-gcp-project

# The name of the Cloud Run job. Probably keep this as is. 
export JOB_NAME=proxy-revision-cleaner
# The name of the service account that the Cloud Run job will use. Probably keep this as is. 
export JOB_SERVICE_ACCOUNT=${JOB_NAME}-sa
# The region where the job will run
export JOB_REGION=us-west1

# Number of revisions to retain
export REVISIONS_TO_KEEP=3

# The name of the custom role for this job. 
export CUSTOM_ROLE_ID=apigeeProxyRevisionReaper

# The name of the job and SA for the scheduler
export SCHEDULER_JOB_NAME=proxy-cleaner-scheduler
export SCHEDULER_SERVICE_ACCOUNT=${SCHEDULER_JOB_NAME}-sa


# try https://crontab.guru/#2_*/3_*_*_* to get a schedule string.
# Eg, every day, at 23:54
export SCHEDULE="54 23 * * *"
# The timezone that this time is relative to
export SCHEDULE_TZ="America/Los_Angeles"
