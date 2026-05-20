# -------------------------------------------------------
# CASE 03 - Secrets Leaked on GitHub (Toyota 2022)
# -------------------------------------------------------
# This file creates:
#   - leaked-dev-user   : simulates a developer whose access key
#                         was hardcoded in public GitHub source code
#   - leaked access key : the "hardcoded" key found in the repo
#   - minimal policy    : read-only on the specific bucket only
#                         but attacker can still exfiltrate all data
# -------------------------------------------------------

resource "aws_iam_user" "leaked_dev" {
  name = "${var.prefix}-leaked-dev-user"
  path = "/"

  tags = {
    Name    = "${var.prefix}-leaked-dev-user"
    Lab     = "Case-03-Secrets-GitHub"
    Role    = "developer"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_access_key" "leaked_dev" {
  user = aws_iam_user.leaked_dev.name
}

# -------------------------------------------------------
# POLICY - Simulates what a developer service account has
# Read access to the customer data bucket
# This is the key that was hardcoded in the GitHub repo
# -------------------------------------------------------

resource "aws_iam_policy" "leaked_dev_policy" {
  name        = "${var.prefix}-leaked-dev-policy"
  description = "Simulates a developer service account with S3 read access - key was hardcoded in GitHub"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3CustomerDataRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.prefix}-tconnect-customer-data",
          "arn:aws:s3:::${var.prefix}-tconnect-customer-data/*"
        ]
      },
      {
        Sid    = "AllowSTSGetCallerIdentity"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-leaked-dev-policy"
    Lab     = "Case-03-Secrets-GitHub"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_user_policy_attachment" "leaked_dev_attach" {
  user       = aws_iam_user.leaked_dev.name
  policy_arn = aws_iam_policy.leaked_dev_policy.arn
}
