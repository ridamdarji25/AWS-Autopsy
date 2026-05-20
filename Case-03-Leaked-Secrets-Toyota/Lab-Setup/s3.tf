# -------------------------------------------------------
# S3 BUCKETS - Case 03
# tconnect-customer-data : simulates Toyota T-Connect customer DB
#                          accessible via the hardcoded key found on GitHub
# -------------------------------------------------------

resource "aws_s3_bucket" "tconnect_customer_data" {
  bucket        = "${var.prefix}-tconnect-customer-data"
  force_destroy = true

  tags = {
    Name    = "${var.prefix}-tconnect-customer-data"
    Lab     = "Case-03-Secrets-GitHub"
    Access  = "should-be-private"
    Project = "AWS-Autopsy"
  }
}

resource "aws_s3_bucket_versioning" "tconnect_versioning" {
  bucket = aws_s3_bucket.tconnect_customer_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tconnect_block" {
  bucket = aws_s3_bucket.tconnect_customer_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tconnect_sse" {
  bucket = aws_s3_bucket.tconnect_customer_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# -------------------------------------------------------
# SIMULATED CUSTOMER DATA
# Mirrors what was exposed in the Toyota T-Connect breach
# email addresses + customer management numbers
# -------------------------------------------------------

resource "aws_s3_object" "customer_emails" {
  bucket       = aws_s3_bucket.tconnect_customer_data.id
  key          = "customers/email-list-2017-2022.csv"
  content      = "customer_id,email,registration_date,vehicle_vin\nTC-001,alice.yamamoto@example.com,2017-12-01,JT3HP10V9X0123456\nTC-002,bob.tanaka@example.com,2018-03-15,JT3HP10V9X0234567\nTC-003,carol.suzuki@example.com,2018-07-22,JT3HP10V9X0345678\nTC-004,david.sato@example.com,2019-01-10,JT3HP10V9X0456789\nTC-005,emily.ito@example.com,2019-05-30,JT3HP10V9X0567890\nTC-006,frank.watanabe@example.com,2020-02-14,JT3HP10V9X0678901\nTC-007,grace.kobayashi@example.com,2020-09-01,JT3HP10V9X0789012\nTC-008,henry.nakamura@example.com,2021-04-17,JT3HP10V9X0890123\nTC-009,irene.kimura@example.com,2021-11-25,JT3HP10V9X0901234\nTC-010,james.matsumoto@example.com,2022-06-08,JT3HP10V9X1012345"
  content_type = "text/csv"
}

resource "aws_s3_object" "customer_management" {
  bucket       = aws_s3_bucket.tconnect_customer_data.id
  key          = "customers/management-numbers.json"
  content      = jsonencode({
    total_customers = 296019
    export_date     = "2022-09-15"
    service         = "T-Connect"
    note            = "CONFIDENTIAL - customer management numbers and email addresses"
    sample = [
      { mgmt_id = "MGMT-00001", email = "alice.yamamoto@example.com", status = "active" },
      { mgmt_id = "MGMT-00002", email = "bob.tanaka@example.com", status = "active" },
      { mgmt_id = "MGMT-00003", email = "carol.suzuki@example.com", status = "inactive" }
    ]
  })
  content_type = "application/json"
}

resource "aws_s3_object" "vehicle_location_data" {
  bucket       = aws_s3_bucket.tconnect_customer_data.id
  key          = "telemetry/vehicle-location-log.json"
  content      = jsonencode({
    note = "CONFIDENTIAL - vehicle GPS telemetry data"
    records = [
      { vin = "JT3HP10V9X0123456", lat = 35.6762, lon = 139.6503, timestamp = "2022-09-01T08:32:00Z", speed_kmh = 42 },
      { vin = "JT3HP10V9X0234567", lat = 34.6937, lon = 135.5023, timestamp = "2022-09-01T09:15:00Z", speed_kmh = 0 },
      { vin = "JT3HP10V9X0345678", lat = 35.0116, lon = 135.7681, timestamp = "2022-09-01T10:01:00Z", speed_kmh = 60 }
    ]
  })
  content_type = "application/json"
}

resource "aws_s3_object" "app_config_with_secret" {
  bucket       = aws_s3_bucket.tconnect_customer_data.id
  key          = "config/app-config.json"
  content      = jsonencode({
    note            = "SIMULATED - This represents the type of config file found in the leaked GitHub repo"
    db_host         = "tconnect-prod-db.internal.toyota.example.com"
    db_name         = "tconnect_customers"
    db_user         = "tconnect_svc"
    aws_region      = "us-east-1"
    environment     = "production"
    warning         = "ACCESS KEY FOR THIS BUCKET WAS HARDCODED IN SOURCE CODE PUSHED TO PUBLIC GITHUB"
  })
  content_type = "application/json"
}
