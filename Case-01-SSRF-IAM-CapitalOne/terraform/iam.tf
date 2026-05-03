resource "aws_iam_role" "autopsy_role" {
  name = "${var.prefix}-autopsy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_overpermissive" {
  name = "${var.prefix}-autopsy-s3-full"
  role = aws_iam_role.autopsy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "autopsy_profile" {
  name = "${var.prefix}-autopsy-profile"
  role = aws_iam_role.autopsy_role.name
}