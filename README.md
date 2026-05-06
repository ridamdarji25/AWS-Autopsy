# 🔪 The AWS Autopsy
<br>
<img width="1731" height="909" alt="AWS-Autopsy" src="https://github.com/user-attachments/assets/236d8684-d69f-4e63-8e81-9fb56622da0a" />

<br>

> Real AWS breaches. Dissected. Hands-on labs. Terraform included.

---

## What is this?

Most cloud security content tells you **what** went wrong.

This series shows you **exactly how** — by rebuilding every attack in a real AWS environment, step by step, so you can see it, understand it, and stop it.

Every case is based on a **real breach**. Real company. Real damage. Real fix.

---

## ⚠️ Legal & Ethical Disclaimer

This repository is created **strictly for educational and defensive security research.**

- ✅ Run all labs **only** on AWS infrastructure you personally own
- ✅ Intended to help engineers **understand and defend** against real attack vectors
- ❌ Do **not** use any technique shown here on systems you do not own
- ❌ Do **not** use this for any malicious, unauthorized, or illegal activity
- ❌ Unauthorized access to computer systems is a **criminal offense**

> The author takes no responsibility for any misuse of the information in this repository.

---

## Cases

| Case | Breach | Company | Attack Vector | Status |
|------|--------|---------|---------------|--------|
| [Case #01](./Case-01-SSRF-IAM-CapitalOne/) | SSRF → IAM Credential Theft | Capital One — $80M fine | SSRF + IMDSv1 + Overpermissive IAM | ✅ Live |

---

## Each Case Contains

```
Case-XX-Name/
├── LabSetup/        ← deploy the vulnerable lab
└── writeup/         ← full technical article (Hashnode / Medium)

```

---

## How to Use

```bash
# Clone the repo
git clone https://github.com/ridamdarji25/AWS-Autopsy

# Go to any case
cd AWS-Autopsy/Case-01-SSRF-IAM-CapitalOne/terraform

# Set your unique prefix in terraform.tfvars
prefix = "yourname"

# Deploy the lab
terraform init
terraform apply

# Follow the exploit guide
cd ../writeup
```

> Always run `terraform destroy` when done to avoid unexpected AWS charges.

---

## Prerequisites

- AWS account (free tier works for most labs)
- AWS CLI configured — `aws configure`
- Terraform v1.3+ installed
- Basic familiarity with AWS IAM and EC2

---

## Series

Follow the full series on:

- 💼 **LinkedIn** — [linkedin.com/in/ridamdarji](https://linkedin.com/in/ridamdarji) — posts every Monday + Thursday
- 📖 **Hashnode** — [awsautopsy.hashnode.dev](https://awsautopsy.hashnode.dev) — full technical writeups
- 🏗️ **AWS Builder Community** — detailed lab walkthroughs

---

## Author

**Ridam Darji**
AWS Security Researcher · Cloud Security Engineer

If you find this useful — ⭐ star the repo.
It helps others find the series.

---

*The AWS Autopsy — Real cloud breaches, dissected.*
