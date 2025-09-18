## Cloud Run job to remove old Apigee Proxy revisions

This is a setup script to provision a Cloud Run Job, as well as a schedule for
that Job, to removes older proxy revisions in Apigee or hybrid.

## Details

With each import of a "Proxy bundle" into Apigee X, 
there will be a new revision created. Without some sort of 
grooming or culling, these revisions accumulate without bound. 

It's no fun using the UI to click-to-delete the older revisions. 

I created [cleanOldRevisions.js](https://github.com/DinoChiesa/apigee-edge-js-examples/blob/main/cleanOldRevisions.js) for that purpose. 

You can run it like this from the command line:

```sh
node ./cleanOldRevisions.js -o my-gcp-project-name -K 3 --token $TOKEN --apigeex -v
```

It never removes deployed revisions and keeps the number of old revisions of
each proxy that you prefer. While it avoids the tedious clicking through the UI,
it does require manually executing the script every so often.

To automate this, I produced this repository which provide screipts that provision
that script as a Cloud Run job that runs on a schedule.  The result is you can
have that script run on a nightly basis, keeping only the number of old
revisions you like.

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

This job will run using the Principle of Least Privilege. The setup uses a custom Role with these permissions: 
- apigee.deployments.list
- apigee.deployments.get
- apigee.proxyrevisions.list
- apigee.proxyrevisions.get
- apigee.proxyrevisions.delete

The Cloud Run job runs as a service account _with that role_  in the Apigee project. 



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

4. Create the job:
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

- you can specify only one Apigee project in the Cloud Run Job
