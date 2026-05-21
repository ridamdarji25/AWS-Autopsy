# Case #03 — Secrets Leaked on GitHub: How Toyota Exposed 300,000 Customers for Five Years

**Series: The AWS Autopsy — Real Cloud Breaches, Dissected**
**Difficulty:** Beginner-Intermediate
**Lab Time:** ~25 minutes
**AWS Cost:** Near zero (IAM + S3 only — free tier eligible)

**GitHub:** [AWS-Autopsy | Case #03](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-03-Leaked-Secrets-Toyota)

---

## ⚠️ Legal & Ethical Disclaimer

This article and the accompanying lab are created strictly for educational and defensive security research purposes.

✅ Run this lab only on AWS infrastructure you personally own

✅ This is intended to help security professionals understand and defend against real attack vectors

❌ Do not use any technique shown here on systems you do not own

❌ Do not use this for any malicious, unauthorized, or illegal activity

❌ Unauthorized access to computer systems is a criminal offense in most countries

By continuing, you agree that you are using this content solely for ethical security research and education. The author takes no responsibility for any misuse of the information presented.

<img width="1096" height="449" alt="image" src="https://github.com/user-attachments/assets/b1ac9d9f-5b10-4431-8a5c-b80dd4d9f7a0" />
<br>
</br>

---

## The Victim

| Field | Details |
|-------|---------|
| Organisation | Toyota Motor Corporation |
| Service Affected | T-Connect (vehicle connectivity app) |
| Date of Exposure Start | December 2017 |
| Date Discovered | September 2022 |
| Duration of Exposure | ~5 years |
| Customers Affected | 296,019 |
| Data Exposed | Email addresses + customer management numbers |
| Root Cause | AWS access key hardcoded in source code pushed to public GitHub |

---

## The Story

Most developers know they shouldn't hardcode credentials.

Most developers do it anyway — just once, just temporarily, just to test something quickly.

That is exactly what happened at Toyota.

In December 2017, a development subcontractor working on Toyota's T-Connect service pushed a portion of the site's source code to a public GitHub repository. T-Connect is Toyota's official vehicle connectivity app — it links smartphones to car infotainment systems for navigation, calls, music, and driving data across millions of vehicles.

Inside that source code was an AWS access key. Hardcoded. Pointing directly at the T-Connect customer database on S3.

The repository sat publicly accessible for nearly five years. From December 2017 to September 15, 2022, anyone who found the repository — a security researcher, a curious developer, an automated scanner, or a malicious actor — could have used that key to access the email addresses and customer management numbers of 296,019 Toyota customers.

When Toyota finally discovered the exposure and investigated, they issued a statement saying they could neither confirm nor deny whether the data had been accessed by an unauthorised third party. Five years of potential exposure. No definitive answer.

Toyota blamed the development subcontractor but accepted responsibility. The source code was made private. The key was rotated. Affected customers were warned to watch for phishing emails.

That was all that could be done.

---

## This Is Not a Toyota Problem

Before we go further — Toyota is not uniquely careless.

This is one of the most common security failures in software development, happening at organisations of every size and level of sophistication:

| Organisation | Year | Secrets Exposed |
|-------------|------|----------------|
| Samsung | 2022 | 6,695 secrets in GitHub repos |
| Nvidia | 2022 | Internal credentials in leaked repos |
| Twitch | 2022 | Hardcoded keys in leaked source code |
| Toyota | 2022 | AWS key in public GitHub repo for 5 years |
| Multiple | Every year | GitGuardian detected 10 million secrets on GitHub in 2022 alone |

Automated bots scan GitHub continuously. When a new commit is pushed containing an AWS access key pattern, it can be detected, tested, and used within minutes. The key does not need to be there long. But when it stays for five years, the window is catastrophic.

---

## The Kill Chain

```
[Developer]
    │
    │  Writes T-Connect app source code
    │  Hardcodes AWS access key for local testing
    │
    ▼
[git push → public GitHub repository]
    │
    │  Source code now publicly accessible
    │  AWS_ACCESS_KEY_ID visible in plain text
    │
    ▼
[Automated scanners — GitGuardian, truffleHog, custom bots]
    │
    │  Scan every public push within minutes
    │  Detect AWS key pattern
    │  Test key validity via sts:GetCallerIdentity
    │
    ▼
[Valid key confirmed — S3 access to T-Connect customer bucket]
    │
    │  aws s3 sync → download all customer data
    │
    ▼
[296,019 customer emails + management numbers]
    │
    │  5 years of undetected exposure
    │
    ▼
[Toyota cannot confirm or deny data was accessed]
```

**Attack Complexity:** TRIVIAL
**Preventability:** 100%

---

## Lab Architecture

This lab simulates the Toyota attack scenario end to end:

- **leaked-dev-user** — IAM user representing the developer whose key was in the GitHub repo
- **tconnect-customer-data bucket** — S3 bucket simulating the Toyota T-Connect customer database
- **simulate_github_leak.py** — a Python file showing exactly what the leaked source code looked like with hardcoded credentials inside
- Simulated customer data: email list, management numbers, vehicle telemetry, app config

**The scenario:** You "find" the leaked key in a public GitHub repo. You configure it as an AWS profile. You use it to list and download all customer data. Then you implement proper secret management.

> **📌 Note:** This lab is inspired by the Toyota T-Connect breach and simulates the same class of vulnerability for learning purposes. It is not an exact technical replica of Toyota's internal infrastructure — exact details of their environment are not publicly known. The attack pattern, credentials-in-code vector, and S3 data exposure are representative of what occurred, built here so you can experience and understand the risk firsthand.

---

## Prerequisites

- AWS account (free tier works)
- AWS CLI v2 configured (`aws configure`)
- Terraform v1.3+ installed
- Python 3.x + pip3

---

## Part 1 — Lab Setup

**Clone the repository:**

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy
cd AWS-Autopsy/Case-03-Secrets-GitHub-Toyota/LabSetup
```
<img width="1024" height="275" alt="image" src="https://github.com/user-attachments/assets/8b809562-be74-42de-86a8-f8d90f333578" />
<br>
</br>

**Verify terraform.tfvars:**

```hcl
region = "us-east-1"
prefix = "yourname"
```
<img width="981" height="224" alt="image" src="https://github.com/user-attachments/assets/587421de-a6b4-4e22-b344-f7526f4f8393" />
<br>
</br>

**Deploy the lab:**

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted.

**Note the outputs:**

```
leaked_dev_user_name     = "yourname-leaked-dev-user"
leaked_access_key_id     = "AKIAXXXXXXXXXXXXXXXXX"
tconnect_bucket_name     = "yourname-tconnect-customer-data"
```
<img width="748" height="132" alt="Screenshot 2026-05-21 082819" src="https://github.com/user-attachments/assets/4acaf9fe-09a4-4446-8a1f-bf09bbff4a9a" />
<br>
</br>

---

## Part 2 — The Attack

> ⚠️ Perform these steps only on your own lab.

### Step 1 — "Find" the Key on GitHub

> 🎭 **This is simulated.** In the real Toyota breach, an actual AWS key was hardcoded inside T-Connect source code on a public GitHub repo. Here we recreate the same scenario for learning purposes, you don't need to hunt for credentials in any file. The **Access Key ID already appeared in your terminal** right after `terraform apply` as part of the outputs. For the Secret Access Key, run this — the `--raw` flag removes the surrounding quotes so you can copy it cleanly:

```python
# HARDCODED CREDENTIALS - THIS IS THE VULNERABILITY
AWS_ACCESS_KEY_ID     = "AKIAXXXXXXXXXXXXXXXX"      # <- found in the public repo
AWS_SECRET_ACCESS_KEY = "XXXXXXXXXXXXXXXXXXXXXXXX"   # <- sitting in plain text
AWS_REGION            = "us-east-1"
CUSTOMER_BUCKET       = "yourname-tconnect-customer-data"
```


```bash
terraform output -raw leaked_secret_access_key
```
<img width="929" height="131" alt="Screenshot 2026-05-21 082948" src="https://github.com/user-attachments/assets/b72b3e18-b2d2-4094-b6c2-85b294f1a1a0" />
<br>
</br>

Copy both values. You'll use them in the next step.

---





### Step 2 — Configure the Leaked Profile

> 🎭 **Mindset for this step:** You just found `simulate_github_leak.py` on a public GitHub repo. AWS keys are sitting in plain text inside the file. You copy them and do exactly what any attacker — or automated scanner bot — would do next: configure the keys locally and test if they actually work.

```bash
aws configure --profile leaked
# AWS Access Key ID     : (paste leaked_access_key_id from terraform output)
# AWS Secret Access Key : (paste leaked_secret_access_key from terraform output -raw)
# Default region name   : us-east-1
# Default output format : json

```
<img width="888" height="153" alt="Screenshot 2026-05-21 083848" src="https://github.com/user-attachments/assets/b5bff1a7-40f4-470a-b21a-da77c177cba0" />
<br>
</br>

---

### Step 3 — Verify the Key is Valid

```bash
aws sts get-caller-identity --profile leaked
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "XXXXXXXXXXXX",
    "Arn": "arn:aws:iam::XXXXXXXXXXXX:user/yourname-leaked-dev-user"
}
```

The key works. The attacker now has confirmed access.

<img width="954" height="185" alt="Screenshot 2026-05-21 084351" src="https://github.com/user-attachments/assets/08ed17e7-f1b4-4bd0-8f59-40b89d7e9851" />
<br>
</br>

---

### Step 4 — List Customer Data

```bash
aws s3 ls s3://yourname-tconnect-customer-data --profile leaked --recursive
```

Expected output:

```
2022-09-15 10:00:00       512 config/app-config.json
2022-09-15 10:00:00      1024 customers/email-list-2017-2022.csv
2022-09-15 10:00:00       768 customers/management-numbers.json
2022-09-15 10:00:00       640 telemetry/vehicle-location-log.json
```

All customer data. Fully visible. One command.

<img width="996" height="158" alt="Screenshot 2026-05-21 084552" src="https://github.com/user-attachments/assets/467636ef-f9eb-47b4-8363-50c3e8c43650" />
<br>
</br>

---

### Step 5 — Download All Customer Records

```bash
aws s3 sync s3://yourname-tconnect-customer-data ./stolen-toyota-data --profile leaked
```

Expected output:

```
download: s3://yourname-tconnect-customer-data/customers/email-list-2017-2022.csv
download: s3://yourname-tconnect-customer-data/customers/management-numbers.json
download: s3://yourname-tconnect-customer-data/telemetry/vehicle-location-log.json
download: s3://yourname-tconnect-customer-data/config/app-config.json
```

<img width="1228" height="258" alt="image" src="https://github.com/user-attachments/assets/00d0e54a-d3c2-41c1-88e4-1a84c4b2f32f" />
<br>
</br>

View the stolen customer data:

```bash
cat stolen-toyota-data/customers/email-list-2017-2022.csv
```

Expected output:

```
customer_id,email,registration_date,vehicle_vin
TC-001,alice.yamamoto@example.com,2017-12-01,JT3HP10V9X0123456
TC-002,bob.tanaka@example.com,2018-03-15,JT3HP10V9X0234567
...
```

```bash
cat stolen-toyota-data/customers/management-numbers.json
```

<img width="933" height="319" alt="image" src="https://github.com/user-attachments/assets/530534e9-140e-46ad-9c68-c9d759b5db08" />
<br>
</br>

---

## Part 3 — Detection

### What Should Have Caught This Immediately

**GitHub Secret Scanning (Native — Free)**

GitHub natively scans public repositories for AWS key patterns and automatically alerts AWS to revoke detected keys. This feature exists and is enabled by default on public repos.

For private repos, enable it under:
`Settings → Security → Secret scanning`

**GitGuardian (Industry Standard)**

GitGuardian monitors every public GitHub push in real time and alerts repository owners when credentials are detected.

```bash
# Install ggshield for pre-commit scanning
pip install ggshield
ggshield secret scan pre-commit
```

**AWS CloudTrail — What to Look For**

Any use of the leaked key would appear in CloudTrail:

```sql
SELECT
  eventTime,
  userIdentity.arn,
  sourceIPAddress,
  eventName,
  requestParameters
FROM cloudtrail_logs
WHERE
  userIdentity.userName = 'yourname-leaked-dev-user'
  AND eventSource = 's3.amazonaws.com'
ORDER BY eventTime DESC
LIMIT 50;
```

Unexpected `GetObject` or `ListBucket` calls from unknown IP addresses using a developer service account should trigger immediate alerts.

**AWS GuardDuty**

GuardDuty raises `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` when credentials are used from unexpected locations. Enable it in one line:

```bash
aws guardduty create-detector --enable --region us-east-1
```

---

## Part 4 — Remediation

### Fix 1 — Never Hardcode. Use AWS Secrets Manager.

**Before (vulnerable):**

```python
AWS_ACCESS_KEY_ID     = "AKIAXXXXXXXXXXXXXXXX"
AWS_SECRET_ACCESS_KEY = "XXXXXXXXXXXXXXXXXXXXXXXX"

s3 = boto3.client(
    "s3",
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY
)
```

**After (correct):**

```python
import boto3

# No credentials in code
# The application uses its IAM role automatically
s3 = boto3.client("s3", region_name="us-east-1")
```

When running on EC2, ECS, or Lambda, boto3 automatically uses the attached IAM role. No keys needed in code. No keys to leak.

For secrets that genuinely need to be stored (database passwords, API tokens), use AWS Secrets Manager:

```python
import boto3
import json

def get_secret(secret_name):
    client = boto3.client("secretsmanager", region_name="us-east-1")
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

# Usage
config = get_secret("tconnect/db-config")
db_password = config["password"]
```

---

### Fix 2 — Pre-Commit Hooks with git-secrets

Install git-secrets to block commits containing AWS key patterns before they ever reach GitHub:

```bash
# Install
brew install git-secrets         # macOS
apt install git-secrets          # Ubuntu

# Setup for your repo
cd your-repo
git secrets --install
git secrets --register-aws

# Now try to commit a file with an AWS key
# It will be blocked automatically
git add file-with-key.py
git commit -m "add config"
# ERROR: Matched one or more prohibited patterns
```

This runs before every commit. The key never reaches GitHub.

---

### Fix 3 — Rotate the Compromised Key Immediately

If a key has been leaked, rotation is the only fix. Deletion from Git history is not enough — the key exists in cached copies, forks, and scanner databases.

```bash
# Step 1 — Create a new access key
aws iam create-access-key --user-name yourname-leaked-dev-user

# Step 2 — Update all applications using the old key

# Step 3 — Deactivate the old key
aws iam update-access-key \
  --user-name yourname-leaked-dev-user \
  --access-key-id OLD_KEY_ID \
  --status Inactive

# Step 4 — Delete the old key after confirming everything works
aws iam delete-access-key \
  --user-name yourname-leaked-dev-user \
  --access-key-id OLD_KEY_ID
```

---

## Cleanup

```bash
terraform destroy
```
<img width="1079" height="204" alt="image" src="https://github.com/user-attachments/assets/2754831e-5e01-4bbb-97c4-da62246bfaa1" />
<br>
</br>

---

## The 3 Lessons from Case #03

**1/ A secret committed to Git is never truly deleted**
`git rm` removes the file from the current state, but the secret still exists in commit history. Anyone can run `git log` or clone the full history and find it. The only real fix is immediate key rotation. Prevention is the only reliable protection.

**2/ Public repos are scanned by bots within minutes of every push**
Automated tools run continuously against GitHub, looking for AWS key patterns, private keys, tokens, and connection strings. Assume any secret that touches a public repo has been seen. Immediately.

**3/ If you cannot confirm whether data was accessed, your monitoring is also broken**
Toyota could not tell whether their customer data had been accessed over five years. That is two failures — the leaked key and the absent logging. CloudTrail + GuardDuty + alerting are not optional. They are the difference between a breach you respond to in minutes and one you discover five years later.

---

## What's Next

**Case #04 — CloudTrail Blind Spot (Twitch 125GB Breach)**

An attacker exfiltrated 125GB of Twitch source code, creator payouts, and internal tools. The most interesting part was not what they stole — it was how long they moved around undetected. We'll dig into CloudTrail gaps, logging misconfigurations, and how attackers avoid leaving traces.

Follow on [LinkedIn](https://linkedin.com/in/ridamdarji) and [GitHub](https://github.com/ridamdarji25) so you don't miss it.

⭐ Star the repo → [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)

---

## References

- [Toyota T-Connect Data Breach Disclosure — October 2022](https://www.toyota.co.jp)
- [BleepingComputer — Toyota discloses data leak after access key exposed on GitHub](https://www.bleepingcomputer.com/news/security/toyota-discloses-data-leak-after-access-key-exposed-on-github)
- [GitGuardian — State of Secrets Sprawl 2023](https://www.gitguardian.com/state-of-secrets-sprawl-report)
- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [GitHub Secret Scanning Documentation](https://docs.github.com/en/code-security/secret-scanning)
- [git-secrets by AWS Labs](https://github.com/awslabs/git-secrets)
- [MITRE ATT&CK — Unsecured Credentials: Credentials in Files](https://attack.mitre.org/techniques/T1552/001)

---

*The AWS Autopsy is an educational series on real cloud security incidents. Every technique demonstrated is for defensive security research only. Always obtain proper authorisation before testing any system you do not own.*

*Found this useful? Share it with your team. Every developer should understand why credentials do not belong in code.*

**Tags:** aws cloud-security github secret-management terraform devsecops security-research toyota ethical-hacking

`#aws` `#cloud-security` `#github` `#devsecops` `#terraform` `#cybersecurity` `#secret-management` `#security-research`
