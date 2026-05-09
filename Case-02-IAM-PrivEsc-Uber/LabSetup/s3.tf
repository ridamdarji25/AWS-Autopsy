resource "aws_s3_bucket" "public_bucket" {
  bucket        = "${var.prefix}-public-bucket"
  force_destroy = true

  tags = {
    Name    = "${var.prefix}-public-bucket"
    Lab     = "Case-02-IAM-PrivEsc"
    Access  = "low-priv"
    Project = "AWS-Autopsy"
  }
}

resource "aws_s3_bucket_versioning" "public_bucket_versioning" {
  bucket = aws_s3_bucket.public_bucket.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "public_bucket_block" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "public_file" {
  bucket       = aws_s3_bucket.public_bucket.id
  key          = "welcome.txt"
  content      = "Welcome to Uber internal portal. You have read-only access."
  content_type = "text/plain"
}

# -------------------------------------------------------
# SENSITIVE BUCKET (attacker CANNOT access at start)
# Contains simulated PII and financial records
# -------------------------------------------------------

resource "aws_s3_bucket" "sensitive_bucket" {
  bucket        = "${var.prefix}-sensitive-bucket"
  force_destroy = true

  tags = {
    Name    = "${var.prefix}-sensitive-bucket"
    Lab     = "Case-02-IAM-PrivEsc"
    Access  = "restricted"
    Project = "AWS-Autopsy"
  }
}

resource "aws_s3_bucket_versioning" "sensitive_bucket_versioning" {
  bucket = aws_s3_bucket.sensitive_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "sensitive_bucket_block" {
  bucket = aws_s3_bucket.sensitive_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sensitive_bucket_sse" {
  bucket = aws_s3_bucket.sensitive_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "sensitive_rider_data" {
  bucket       = aws_s3_bucket.sensitive_bucket.id
  key          = "rider-pii/user-data-2022.csv"
  content      = "user_id,name,email,phone,trip_count\n1001,Alice Johnson,alice@example.com,+1-555-0101,47\n1002,Bob Smith,bob@example.com,+1-555-0102,112\n1003,Carol White,carol@example.com,+1-555-0103,8"
  content_type = "text/csv"
}

resource "aws_s3_object" "sensitive_financial" {
  bucket       = aws_s3_bucket.sensitive_bucket.id
  key          = "financial/q3-2022-revenue.txt"
  content      = "CONFIDENTIAL - Q3 2022 Revenue Report\nTotal Revenue: $8.34B\nNet Loss: $-520M\nDriver Payouts: $3.1B\n[INTERNAL USE ONLY]"
  content_type = "text/plain"
}

resource "aws_s3_object" "sensitive_hackerone" {
  bucket       = aws_s3_bucket.sensitive_bucket.id
  key          = "security/unpatched-vulns.txt"
  content      = "CRITICAL - Unpatched Vulnerabilities (HackerOne Private)\n- CVE-INTERNAL-001: SQL injection in driver portal\n- CVE-INTERNAL-002: IDOR in payment API\n- CVE-INTERNAL-003: Auth bypass in admin dashboard\n[DO NOT SHARE OUTSIDE SECURITY TEAM]"
  content_type = "text/plain"
}
