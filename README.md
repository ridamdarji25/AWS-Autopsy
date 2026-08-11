# The AWS Autopsy

> Real AWS breaches. Dissected. Hands-on labs. Terraform included.

---

<img width="1731" height="909" alt="588489164-236d8684-d69f-4e63-8e81-9fb56622da0a" src="https://github.com/user-attachments/assets/aba48981-f0c6-453a-a68f-cecba1b4ea4b" />

---

## What is this?

Most cloud security content tells you what went wrong.

AWS Autopsy shows you how it happened by rebuilding real AWS security incidents in controlled lab environments.

Each case takes a real breach and turns it into a hands-on security lab. You can deploy the environment, follow the attack path, understand what went wrong, and then work through the security fixes.

The goal is simple:

**Read less. Build more. Understand what actually happened.**

---

## What does each case cover?

Every case focuses on a different AWS security problem.

Some cases look at IAM and privilege escalation. Others focus on exposed secrets, cloud logging, or different AWS misconfigurations.

Each case includes:

* Real-world incident background
* AWS attack path
* Terraform lab setup
* Hands-on attack simulation
* Investigation and findings
* Security controls and remediation

The labs use simulated environments and data so the techniques can be studied safely.

---

## Cases

| Case                                                                                                   | Incident    | Focus                                 | Status |
| ------------------------------------------------------------------------------------------------------ | ----------- | ------------------------------------- | ------ |
| [Case #01](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-01-SSRF-IAM-CapitalOne)          | Capital One | SSRF, IMDSv1 and IAM credential theft | Live   |
| [Case #02](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-02-IAM-PrivEsc-Uber)             | Uber        | IAM privilege escalation              | Live   |
| [Case #03](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-03-Leaked-Secrets-Toyota)        | Toyota      | Leaked secrets and cloud exposure     | Live   |
| [Case #04](https://github.com/ridamdarji25/AWS-Autopsy/tree/main/Case-04-Twitch-CloudTrail-Blind-Spot) | Twitch      | CloudTrail blind spots and logging    | Live   |

More cases will be added as the series grows.

---

## Each Case Contains

```text
Case-XX-Name/
├── Lab-Setup/       <- Terraform lab
└── writeup/         <- Technical writeup
```

The `Lab-Setup` directory contains the Terraform files required to build the lab.

The `writeup` directory contains the technical analysis, attack flow, findings, and remediation.

The exact structure can be slightly different depending on the case.

---

## How to Use

Clone the repository:

```bash
git clone https://github.com/ridamdarji25/AWS-Autopsy.git
cd AWS-Autopsy
```

Choose a case:

```bash
cd Case-01-SSRF-IAM-CapitalOne
```

Go to the lab setup:

```bash
cd Lab-Setup
```

Initialize Terraform:

```bash
terraform init
```

Check the resources:

```bash
terraform plan
```

Deploy the lab:

```bash
terraform apply
```

Then follow the instructions inside that case.

When you are finished:

```bash
terraform destroy
```

Always destroy the resources after completing the lab to avoid unnecessary AWS charges.

---

## Prerequisites

You will need:

* AWS account
* AWS CLI
* Terraform v1.3+
* Git
* Basic AWS knowledge
* Basic IAM knowledge
* Basic Linux command-line knowledge

Some cases may require additional tools. Check the individual case before starting.

---

## Legal & Ethical Disclaimer

This repository is created strictly for educational and defensive security research.

Run all labs only on AWS infrastructure that you own or have permission to test.

Do not use the techniques shown here against systems, accounts, applications, or infrastructure without authorization.

The purpose of AWS Autopsy is to understand real cloud security failures and learn how to prevent and detect them.

The author takes no responsibility for any misuse of the information in this repository.

---

## Writeups

The technical writeups for AWS Autopsy are also published online.

### Medium

https://w1tn3sss.medium.com/

### Hashnode

https://awsautopsy.hashnode.dev/

The writeups go deeper into the incident, attack path, AWS services involved, security findings, and remediation.

---

## Follow the Series

You can follow the project and future cases here:

**GitHub**

https://github.com/ridamdarji25/AWS-Autopsy

**LinkedIn**

https://linkedin.com/in/ridamdarji

**Medium**

https://w1tn3sss.medium.com/

**Hashnode**

https://awsautopsy.hashnode.dev/

---

## Author

**Ridam Darji**

Cloud Security | AWS | Security Research

If you find the project useful, feel free to star the repository and share it with others learning cloud security.

---

*The AWS Autopsy*

*Real cloud breaches. Dissected.*
