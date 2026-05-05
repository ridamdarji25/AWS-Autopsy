output "ec2_public_ip" {
  description = "EC2 public IP — use this as EC2_IP in attack steps"
  value       = aws_instance.autopsy.public_ip
}

output "flask_app_url" {
  description = "Flask SSRF app URL"
  value       = "http://${aws_instance.autopsy.public_ip}:5000"
}

output "sensitive_bucket_name" {
  description = "Target S3 bucket name — use in attack step 5"
  value       = aws_s3_bucket.sensitive.id
}

output "iam_role_name" {
  description = "IAM role name — needed for IMDS credentials path"
  value       = aws_iam_role.autopsy_role.name
}

output "lab_summary" {
  description = "Quick reference for attack steps"

  value = <<-EOT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔪 AWS AUTOPSY | CASE #01 — LAB READY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EC2 IP      : ${aws_instance.autopsy.public_ip}
Flask URL   : http://${aws_instance.autopsy.public_ip}:5000
IAM Role    : ${aws_iam_role.autopsy_role.name}
S3 Bucket   : ${aws_s3_bucket.sensitive.id}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next: cd ../exploit && bash attack-steps.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOT
}