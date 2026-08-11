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
