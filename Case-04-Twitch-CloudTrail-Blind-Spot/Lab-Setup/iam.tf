resource "aws_iam_user" "attacker" {
  name = "${var.prefix}-twitch-attacker"
  path = "/"

  tags = {
    Name    = "${var.prefix}-twitch-attacker"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Role    = "attacker"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_access_key" "attacker" {
  user = aws_iam_user.attacker.name
}

resource "aws_iam_policy" "attacker_policy" {
  name        = "${var.prefix}-twitch-attacker-policy"
  description = "Simulates attacker access to Twitch internal git server and S3 source buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3SourceCodeRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.prefix}-twitch-source-code",
          "arn:aws:s3:::${var.prefix}-twitch-source-code/*",
          "arn:aws:s3:::${var.prefix}-twitch-creator-data",
          "arn:aws:s3:::${var.prefix}-twitch-creator-data/*"
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
    Name    = "${var.prefix}-twitch-attacker-policy"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_user_policy_attachment" "attacker_attach" {
  user       = aws_iam_user.attacker.name
  policy_arn = aws_iam_policy.attacker_policy.arn
}

resource "aws_iam_user" "cloudtrail_admin" {
  name = "${var.prefix}-cloudtrail-admin"
  path = "/"

  tags = {
    Name    = "${var.prefix}-cloudtrail-admin"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Role    = "admin"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_access_key" "cloudtrail_admin" {
  user = aws_iam_user.cloudtrail_admin.name
}

resource "aws_iam_policy" "cloudtrail_admin_policy" {
  name        = "${var.prefix}-cloudtrail-admin-policy"
  description = "Allows managing CloudTrail - used to simulate disabling the trail (blind spot)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailManagement"
        Effect = "Allow"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails",
          "cloudtrail:ListTrails",
          "cloudtrail:StartLogging"
        ]
        Resource = "*"
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
    Name    = "${var.prefix}-cloudtrail-admin-policy"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_user_policy_attachment" "cloudtrail_admin_attach" {
  user       = aws_iam_user.cloudtrail_admin.name
  policy_arn = aws_iam_policy.cloudtrail_admin_policy.arn
}
