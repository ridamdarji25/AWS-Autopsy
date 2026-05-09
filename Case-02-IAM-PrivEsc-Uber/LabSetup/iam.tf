resource "aws_iam_user" "attacker" {
  name = "${var.prefix}-attacker-user"
  path = "/"

  tags = {
    Name    = "${var.prefix}-attacker-user"
    Lab     = "Case-02-IAM-PrivEsc"
    Role    = "attacker"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_access_key" "attacker" {
  user = aws_iam_user.attacker.name
}


resource "aws_iam_policy" "attacker_policy" {
  name        = "${var.prefix}-attacker-policy"
  description = "Simulates a misconfigured low-priv policy with IAM escalation path"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.prefix}-public-bucket",
          "arn:aws:s3:::${var.prefix}-public-bucket/*"
        ]
      },
      {
        Sid    = "AllowIAMEnumeration"
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies",
          "iam:ListRoles",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "DANGEROUSAllowPolicyAttach"
        Effect = "Allow"
        Action = [
          "iam:AttachUserPolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "DANGEROUSAllowPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-attacker-policy"
    Lab     = "Case-02-IAM-PrivEsc"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_user_policy_attachment" "attacker_policy_attach" {
  user       = aws_iam_user.attacker.name
  policy_arn = aws_iam_policy.attacker_policy.arn
}

resource "aws_iam_role" "admin_role" {
  name        = "${var.prefix}-internal-service-role"
  description = "Over-permissioned internal service role - escalation target"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Assume"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "AllowSelfAssume"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.attacker.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-internal-service-role"
    Lab     = "Case-02-IAM-PrivEsc"
    Project = "AWS-Autopsy"
  }
}

resource "aws_iam_role_policy_attachment" "admin_role_attach" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.prefix}-permission-boundary"
  description = "Permission boundary - caps max permissions for attacker-user to prevent escalation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.prefix}-public-bucket",
          "arn:aws:s3:::${var.prefix}-public-bucket/*"
        ]
      },
      {
        Sid    = "AllowEnumerationOnly"
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ListAttachedUserPolicies",
          "iam:ListRoles",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyIAMWrite"
        Effect = "Deny"
        Action = [
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:CreatePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicy",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-permission-boundary"
    Lab     = "Case-02-IAM-PrivEsc"
    Project = "AWS-Autopsy"
  }
}

