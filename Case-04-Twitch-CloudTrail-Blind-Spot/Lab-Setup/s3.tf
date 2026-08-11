resource "aws_s3_bucket" "twitch_source_code" {
  bucket        = "${var.prefix}-twitch-source-code"
  force_destroy = true

  tags = {
    Name    = "${var.prefix}-twitch-source-code"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Access  = "internal-only"
    Project = "AWS-Autopsy"
  }
}

resource "aws_s3_bucket_versioning" "source_code_versioning" {
  bucket = aws_s3_bucket.twitch_source_code.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "source_code_block" {
  bucket = aws_s3_bucket.twitch_source_code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source_code_sse" {
  bucket = aws_s3_bucket.twitch_source_code.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Simulated source code files
resource "aws_s3_object" "twitch_client_source" {
  bucket       = aws_s3_bucket.twitch_source_code.id
  key          = "twitch-client/main.go"
  content      = "// CONFIDENTIAL - Twitch Client Source Code\n// Internal Git Server — Not for public distribution\npackage main\n\nfunc main() {\n    // Twitch client entrypoint\n    // Build version: 2021.10.04-internal\n}"
  content_type = "text/plain"
}

resource "aws_s3_object" "twitch_sdk" {
  bucket       = aws_s3_bucket.twitch_source_code.id
  key          = "proprietary-sdk/twitch-sdk-internal.md"
  content      = "# Twitch Internal SDK\n\nCONFIDENTIAL — Internal use only\n\nThis SDK contains proprietary methods for:\n- Stream ingestion pipeline\n- Real-time chat infrastructure\n- Ad insertion service\n- Internal recommendation engine\n\nDo NOT distribute outside Twitch."
  content_type = "text/markdown"
}

resource "aws_s3_object" "vapor_project" {
  bucket       = aws_s3_bucket.twitch_source_code.id
  key          = "amazon-game-studios/vapor-README.md"
  content      = "# Project Vapor\n\nCONFIDENTIAL — Amazon Game Studios\nUNRELEASED — Do not distribute\n\nProject Vapor is an unreleased Steam competitor being developed by Amazon Game Studios.\nThis document and all associated source code are strictly confidential.\n\nTarget launch: TBD\nStatus: Internal development"
  content_type = "text/markdown"
}

resource "aws_s3_object" "internal_security_tools" {
  bucket       = aws_s3_bucket.twitch_source_code.id
  key          = "security-tools/internal-pentest-notes.md"
  content      = "# Twitch Internal Security Tools\n\nCONFIDENTIAL — Twitch Security Team\n\nThis folder contains 120+ internal security tools built by Twitch Security.\nIncludes: vulnerability scanners, internal pentest tooling, detection scripts.\n\nExposing this gives attackers a full map of Twitch's defensive capabilities."
  content_type = "text/markdown"
}

resource "aws_s3_bucket" "twitch_creator_data" {
  bucket        = "${var.prefix}-twitch-creator-data"
  force_destroy = true

  tags = {
    Name    = "${var.prefix}-twitch-creator-data"
    Lab     = "Case-04-CloudTrail-BlindSpot"
    Access  = "internal-only"
    Project = "AWS-Autopsy"
  }
}

resource "aws_s3_bucket_public_access_block" "creator_data_block" {
  bucket = aws_s3_bucket.twitch_creator_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "creator_data_sse" {
  bucket = aws_s3_bucket.twitch_creator_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "creator_payouts" {
  bucket       = aws_s3_bucket.twitch_creator_data.id
  key          = "payouts/creator-earnings-2019-2021.csv"
  content      = "streamer_name,gross_earnings_usd,year\nCriticalRole,9626712,2021\nxQcOW,8454427,2021\nsummit1g,5847541,2021\nImane,5406907,2021\nNickMercs,5096642,2021\nTimTheTatman,3290027,2021\nDrLupo,3177643,2021\nHasanAbi,2784027,2021\nLudwig,2618347,2021\nPokimane,1528356,2021"
  content_type = "text/csv"
}

resource "aws_s3_object" "igdb_data" {
  bucket       = aws_s3_bucket.twitch_creator_data.id
  key          = "igdb/internal-game-database-config.json"
  content      = jsonencode({
    service     = "IGDB - Internet Games Database"
    note        = "CONFIDENTIAL - Twitch internal property"
    db_endpoint = "igdb-prod.internal.twitch.tv"
    warning     = "This configuration was exposed in the October 2021 breach"
  })
  content_type = "application/json"
}
