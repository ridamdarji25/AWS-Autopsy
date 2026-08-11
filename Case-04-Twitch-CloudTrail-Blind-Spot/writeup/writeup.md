# Case #04: Twitch CloudTrail Blind Spot

A hands-on AWS lab based on the 2021 Twitch breach, focused on a specific security problem: what happens when CloudTrail logging is disabled while sensitive data is being accessed.

The lab uses two IAM identities. The `twitch-attacker` user is allowed to access the simulated Twitch S3 data, while the `cloudtrail-admin` user controls the CloudTrail trail. This separation makes it possible to reproduce the attack and observe the difference between activity that is logged and activity that happens during the blind spot.

The data in this lab is simulated. The purpose is to understand how the logging gap happens and why the audit trail itself needs to be protected.

## What This Lab Demonstrates

* S3 access while CloudTrail is running
* Creating a blind spot by stopping CloudTrail
* Accessing data while logging is disabled
* Restoring CloudTrail and inspecting the resulting logs
* Enabling S3 object-level data events
* Detecting attempts to disable CloudTrail

## Lab Walkthrough

### Step 1: Get the Files

Start by updating the AWS Autopsy repository and move into the lab directory.

```bash
cd ~/AWS-Autopsy
git pull origin main

cd Case-04-Twitch-CloudTrail-Blind-Spot/Lab-Setup
ls
```

The directory contains:

```text
provider.tf
variables.tf
terraform.tfvars
iam.tf
s3.tf
cloudtrail.tf
outputs.tf
```

These files contain the complete Terraform configuration required to build the lab.

### Step 2: Deploy the Lab

Initialize Terraform:

```bash
terraform init
```

Review the deployment plan:

```bash
terraform plan
```

If the plan looks correct, deploy the resources:

```bash
terraform apply
```

Type `yes` when prompted.

Terraform creates the IAM users, access keys, S3 buckets, CloudTrail trail, log bucket, and the required IAM policies.

### Step 3: Get the Credentials

The lab requires two different AWS CLI profiles.

Get the attacker credentials:

```bash
terraform output attacker_access_key_id
terraform output -raw attacker_secret_access_key
```

Get the CloudTrail admin credentials:

```bash
terraform output cloudtrail_admin_access_key_id
terraform output -raw cloudtrail_admin_secret_access_key
```

The attacker credentials are used only for accessing the simulated Twitch data. The CloudTrail admin credentials are used to control the logging trail.

Do not commit these credentials to the repository.

### Step 4: Configure AWS Profiles

Configure the attacker profile:

```bash
aws configure --profile twitch-attacker
```

Configure the CloudTrail admin profile:

```bash
aws configure --profile ct-admin
```

Use `us-east-1` for both profiles.

Verify the attacker identity:

```bash
aws sts get-caller-identity --profile twitch-attacker
```

Verify the CloudTrail admin identity:

```bash
aws sts get-caller-identity --profile ct-admin
```

The two profiles should return the expected IAM identities.

### Step 5: Confirm CloudTrail Is Running

Before starting the attack, check the current CloudTrail status:

```bash
aws cloudtrail get-trail-status \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

Look for:

```text
"IsLogging": true
```

This confirms that the first part of the attack will take place while CloudTrail is actively recording events.

## Phase 1: Attack With CloudTrail ON

### Step 6: Access the Source Code

The attacker can read the simulated Twitch source code bucket.

List the objects:

```bash
aws s3 ls s3://w1tn3sss-twitch-source-code \
  --recursive \
  --profile twitch-attacker
```

Download the bucket:

```bash
aws s3 sync \
  s3://w1tn3sss-twitch-source-code \
  ./stolen-twitch \
  --profile twitch-attacker
```

Check the downloaded files:

```bash
ls -la stolen-twitch/
```

For example:

```bash
cat stolen-twitch/amazon-game-studios/vapor-README.md
cat stolen-twitch/security-tools/internal-pentest-notes.md
```

At this point the attacker has successfully accessed the simulated source code while CloudTrail is enabled.

The S3 activity should appear in the CloudTrail logs once the events have been delivered.

## Phase 2: Create the Blind Spot

### Step 7: Stop CloudTrail

Now use the CloudTrail admin profile to stop the trail:

```bash
aws cloudtrail stop-logging \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

Check the status again:

```bash
aws cloudtrail get-trail-status \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

The result should show:

```text
"IsLogging": false
```

The CloudTrail trail still exists, but it is no longer recording new events.

This is the blind spot that the case is designed to reproduce.

## Phase 3: Attack With CloudTrail OFF

### Step 8: Access the Creator Data

The attacker can still access the second simulated S3 bucket.

List the available data:

```bash
aws s3 ls s3://w1tn3sss-twitch-creator-data \
  --recursive \
  --profile twitch-attacker
```

Download the creator data:

```bash
aws s3 sync \
  s3://w1tn3sss-twitch-creator-data \
  ./stolen-twitch/creators \
  --profile twitch-attacker
```

Read the simulated earnings data:

```bash
cat stolen-twitch/creators/payouts/creator-earnings-2019-2021.csv
```

The attacker has successfully accessed another sensitive data set, but CloudTrail is disabled at the time of the access.

This is the important difference between the two attack phases.

The first access happened while the trail was logging. The second access happened while the trail was not logging.

## Phase 4: Restore CloudTrail

### Step 9: Start Logging Again

Restore the CloudTrail trail:

```bash
aws cloudtrail start-logging \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

Verify the status:

```bash
aws cloudtrail get-trail-status \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

The result should now show:

```text
"IsLogging": true
```

CloudTrail will record new activity from this point forward.

It cannot, however, recreate the events that occurred while logging was disabled.

## Phase 5: Inspect the Logs

### Step 10: Check CloudTrail Events

CloudTrail logs are delivered to the S3 log bucket, so wait a few minutes before checking them.

List the available log files:

```bash
aws s3 ls s3://w1tn3sss-cloudtrail-logs --recursive
```

Download the relevant log:

```bash
aws s3 cp \
s3://w1tn3sss-cloudtrail-logs/<path-to-log.json.gz> \
./trail-log.json.gz
```

Decompress it:

```bash
gunzip trail-log.json.gz
```

Inspect the events:

```bash
cat trail-log.json | python3 -m json.tool | grep -A2 "eventName"
```

The expected difference should look like this:

```text
Phase 1 S3 activity  -> Logged
StopLogging          -> Logged
Phase 2 S3 activity  -> Missing
StartLogging         -> Logged
```

The missing Phase 2 activity is the main finding of this case.

The attacker accessed the data successfully, but because CloudTrail was not running at that time, those events were never recorded by the trail.

## Remediation

### Step 11: Enable S3 Data Events

CloudTrail management events are useful for tracking actions such as `StopLogging`, but investigations involving S3 object access also require object-level data events.

Enable S3 object events:

```bash
aws cloudtrail put-event-selectors \
  --trail-name w1tn3sss-autopsy-trail \
  --event-selectors '[{
    "ReadWriteType": "All",
    "IncludeManagementEvents": true,
    "DataResources": [{
      "Type": "AWS::S3::Object",
      "Values": ["arn:aws:s3:::"]
    }]
  }]'
```

Verify the configuration:

```bash
aws cloudtrail get-event-selectors \
  --trail-name w1tn3sss-autopsy-trail
```

The output should show the S3 object data resource.

The Terraform configuration for this lab also defines S3 object-level data events for the CloudTrail trail.

### Step 12: Test the Configuration Again

Stop the trail:

```bash
aws cloudtrail stop-logging \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

Perform another access:

```bash
aws s3 sync \
  s3://w1tn3sss-twitch-creator-data \
  ./stolen-twitch/creators2 \
  --profile twitch-attacker
```

Start the trail again:

```bash
aws cloudtrail start-logging \
  --name w1tn3sss-autopsy-trail \
  --profile ct-admin
```

After the logs are delivered, inspect them again.

The important security control is to monitor CloudTrail management events such as `StopLogging`. If an identity attempts to disable logging, that action should itself become something the security team can detect and investigate.

## Cleanup

### Step 13: Remove the Lab

Remove the downloaded files:

```bash
rm -rf stolen-twitch/
```

Destroy the Terraform resources:

```bash
terraform destroy
```

Type `yes` when prompted.

Finally, verify that the lab resources have been removed:

```bash
aws s3 ls | grep w1tn3sss
```

The command should return no results.

## Key Takeaway

This case is not really about stealing data from S3.

The important part is the visibility gap created when the system responsible for recording the activity is disabled.

With CloudTrail running, the first access leaves evidence. Once CloudTrail is stopped, the attacker can continue accessing the data without those events being recorded by the trail. When logging is restored, future activity becomes visible again, but the missing period remains a blind spot.

That is why CloudTrail should be treated as a security control that also needs to be protected and monitored.
