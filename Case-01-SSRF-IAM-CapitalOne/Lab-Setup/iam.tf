resource "aws_iam_role" "autopsy_role" {
  name = "w1tn3sss-autopsy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "autopsy_policy" {
  name = "w1tn3sss-autopsy-policy"
  role = aws_iam_role.autopsy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",   # 🔥 ye missing tha (main issue)
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "autopsy_profile" {
  name = "w1tn3sss-autopsy-profile"
  role = aws_iam_role.autopsy_role.name
}