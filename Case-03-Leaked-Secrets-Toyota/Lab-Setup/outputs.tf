# -------------------------------------------------------
# OUTPUTS - Case 03
# -------------------------------------------------------

output "leaked_dev_user_name" {
  description = "IAM username of the developer whose key was leaked on GitHub"
  value       = aws_iam_user.leaked_dev.name
}

output "leaked_access_key_id" {
  description = "The access key ID that was hardcoded in GitHub source code"
  value       = aws_iam_access_key.leaked_dev.id
  sensitive   = false
}

output "leaked_secret_access_key" {
  description = "The secret key that was hardcoded in GitHub source code"
  value       = aws_iam_access_key.leaked_dev.secret
  sensitive   = true
}

output "tconnect_bucket_name" {
  description = "S3 bucket containing simulated T-Connect customer data"
  value       = aws_s3_bucket.tconnect_customer_data.bucket
}

output "lab_instructions" {
  description = "Quick start instructions"
  value       = <<-EOT
    ==========================================
    CASE 03 - SECRETS LEAKED ON GITHUB LAB
    ==========================================

    SCENARIO:
    A developer hardcoded AWS credentials in source code
    and pushed it to a PUBLIC GitHub repository.
    The key stayed public for 5 years.
    Anyone who found it could access customer data.

    STEP 1 - Configure the "leaked" profile:
      aws configure --profile leaked
      Access Key ID     : (use leaked_access_key_id output)
      Secret Access Key : run: terraform output -raw leaked_secret_access_key
      Region            : us-east-1

    STEP 2 - Verify the key works (attacker verifies the found key):
      aws sts get-caller-identity --profile leaked

    STEP 3 - List customer data bucket:
      aws s3 ls s3://${aws_s3_bucket.tconnect_customer_data.bucket} --profile leaked --recursive

    STEP 4 - Download all customer data:
      aws s3 sync s3://${aws_s3_bucket.tconnect_customer_data.bucket} ./stolen-toyota-data --profile leaked

    STEP 5 - View the stolen data:
      cat stolen-toyota-data/customers/email-list-2017-2022.csv
      cat stolen-toyota-data/customers/management-numbers.json

    STEP 6 - Run the simulated leaked code:
      pip3 install boto3
      python3 simulate_github_leak.py

    REMEDIATION:
      See writeup/hashnode-article.md for full remediation steps
    ==========================================
  EOT
}
