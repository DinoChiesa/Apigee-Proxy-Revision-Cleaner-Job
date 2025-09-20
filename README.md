## Cloud Run job to remove old Apigee Proxy revisions

This is a setup script to provision a Cloud Run Job, as well as a schedule for
that Job, to removes older proxy revisions in Apigee or hybrid.

## Details

With each import of a "Proxy bundle" into Apigee X, there will be a new revision
created. Without some sort of grooming or culling, these revisions accumulate
without bound.

It's no fun using the UI to click-to-delete the older revisions.

I created
[cleanOldRevisions.js](https://github.com/DinoChiesa/apigee-edge-js-examples/blob/main/cleanOldRevisions.js)
for that purpose.

You can run it like this from the command line:

```sh
node ./cleanOldRevisions.js -o my-gcp-project-name -K 3 --token $TOKEN --apigeex -v
```

It never removes deployed revisions and removes all but the N most recent revisions of
each proxy and sharedflow that you prefer. It avoids the tedious clicking through the UI,
but it still requires manually executing the script every so often.

> BTW, if you want to perform a dry-run:
> ```sh
> node ./cleanOldRevisions.js -o my-gcp-project-name -K 3 --token $TOKEN --apigeex -v --dry-run
> ```

To automate this, I produced this repository which provides bash scripts that
provision that nodejs script as a Cloud Run job that runs on a schedule.  The
result is you can have that nodejs script run on a nightly basis (or weekly, or
hourly, etc.), keeping only the number of old revisions you like.

## Deploying this on your own

To follow the instructions to deploy this in your own environment, you will need the
following pre-requisites:

- Apigee X or hybrid
- a Google Cloud project with Cloud Run and Cloud Build enabled
- various tools: bash, [curl](https://curl.se/),
  [gcloud CLI](https://cloud.google.com/sdk/docs/install),
  [jq](https://jqlang.org/)

You can get all of these things in the [Google Cloud
Shell](https://cloud.google.com/shell/docs/launching-cloud-shell).


## Implementation Notes

1. This job will run using the [Principle of Least
   Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege). The
   setup uses a Custom IAM Role with these [permissions on
   Apigee](https://cloud.google.com/iam/docs/roles-permissions/apigee):

   - `apigee.deployments.list`
   - `apigee.deployments.get`
   - `apigee.proxies.list`
   - `apigee.proxies.get`
   - `apigee.proxyrevisions.list`
   - `apigee.proxyrevisions.get`
   - `apigee.proxyrevisions.delete`
   - `apigee.sharedflowrevisions.list`
   - `apigee.sharedflows.get`
   - `apigee.sharedflows.list`
   - `apigee.sharedflowrevisions.get`
   - `apigee.sharedflowrevisions.delete`

   The Cloud Run job runs as a service account _with that role_ in the Apigee
   project.  It uses the metadata endpoint in Google cloud to get an Access
   Token when it runs.  Because this custom role does not have the ability to
   undeploy proxies or sharedflows, it will be unable to delete a revision that
   is deployed.

2. The job is a nodejs program.  You can specify the Apigee project and the
   number of revisions to keep. It removes old undeployed sharedflows AND
   proxies.

2. The setup script sets the schedule to whatever you prefer. See the
   [env.sh](./env.sh) file for the `SCHEDULE` variable.  You can try using
   [Crontab Guru](https://crontab.guru/#2_*/3_*_*_*) to get a schedule string.
   You can set the schedule to be nightly, hourly, weekly, whatever you prefer.

2. The Cloud Run job will run in a project. It does not have to be the same
   project as your Apigee organization.

2. The Cloud Run job will run in a region. It does not have to be the same
   region as your Apigee instance.

3. The Scheduler will also run in a region. It will be the same region as the
   Cloud Run Job.



## Set up Steps

**Preparation:**
- Modify the [env.sh](./env.sh) file to suit your environment. Then source it to set those
  variables for use in subsequent commands:

  ```sh
  source ./env.sh
  ```

**Steps:**

1. Enable the services needed:
   ```sh
   ./1-enable-services.sh
   ```

2. Create the custom IAM role that the Cloud Run job will use:
   ```sh
   ./2-create-custom-role.sh
   ```

3. Create the service account for the Cloud Run job:
   ```sh
   ./3-create-service-account-for-job.sh
   ```

4. Create the job.

   First, you may want to create a job that performs only a dry-run:
   ```sh
   ./4-create-cleaner-job.sh --dry-run
   ```

   You can test-execute the job right away, if you like.

   After you examine the logs, you will feel comfortable with the expected action.
   At that point you can Re-Create the job, without the --dry-run flag.

   ```sh
   ./4-create-cleaner-job.sh
   ```

5. Schedule the job:
   ```sh
   ./5-create-scheduler.sh
   ```


## Teardown

If you want to remove all these things, you can do so:

1. Remove the scheduler:
   ```sh
   gcloud scheduler jobs delete  "${SCHEDULER_JOB_NAME}" --project="${CLOUDRUN_PROJECT_ID}"  --location "$JOB_REGION"
   ```

2. delete the Scheduler Service account
   ```sh
   SCHEDULER_SA_EMAIL="${SCHEDULER_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
   gcloud iam service-accounts delete ${SCHEDULER_SA_EMAIL} --project "${CLOUDRUN_PROJECT_ID}"
   ```

3. delete the cleaner job from Cloud Run
   ```sh
   gcloud run jobs delete ${JOB_NAME}  --project "${CLOUDRUN_PROJECT_ID}"
   ```

4. delete the Service Account for the cleaner job
   ```sh
   JOB_SA_EMAIL="${JOB_SERVICE_ACCOUNT}@${CLOUDRUN_PROJECT_ID}.iam.gserviceaccount.com"
   gcloud iam service-accounts delete ${JOB_SA_EMAIL} --project "${CLOUDRUN_PROJECT_ID}"
   ```

5. delete the custom role for the Service Account
   ```sh
   gcloud iam roles delete ${CUSTOM_ROLE_ID} --project=${APIGEE_PROJECT_ID}
   ```

## Disclaimer

This example is not an official Google product, nor is it part of an
official Google product.

## License

This material is [Copyright © 2025 Google LLC](./NOTICE).
and is licensed under the [Apache 2.0 License](LICENSE).


## Support

This repository contains open-source software, and is not a supported part of
Apigee.  If you have questions or need assistance with it, you can try inquiring on [the
Google Cloud Community forum dedicated to Apigee](https://goo.gle/apigee-community)
There is no service-level guarantee for responses to inquiries posted to that site.


## Bugs

- You can specify only one Apigee project to the Cloud Run Job.  Ideally, it
  should accept multiple projects. For now, you need to configure multiple jobs
  to clean old revisions from multiple projects. This might be best for hygiene
  purposes anyway.
