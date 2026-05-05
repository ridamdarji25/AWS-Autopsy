resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "sensitive" {
  bucket        = "${var.prefix}-autopsy-sensitive-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "sensitive" {
  bucket = aws_s3_bucket.sensitive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "sensitive" {
  bucket                  = aws_s3_bucket.sensitive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "customer_records" {
  bucket       = aws_s3_bucket.sensitive.id
  key          = "customer-data/records.csv"
  content_type = "text/csv"
  content      = "id,name,ssn,card\n1,John Doe,XXX-XX-1234,4111111111111111\n2,Jane Smith,XXX-XX-5678,4222222222222222"
}

resource "aws_s3_object" "internal_config" {
  bucket       = aws_s3_bucket.sensitive.id
  key          = "internal/db-config.json"
  content_type = "application/json"

  content = jsonencode({
    db_host     = "prod-db.internal.example.com"
    db_password = "DUMMY_FOR_LAB_ONLY"
  })
}