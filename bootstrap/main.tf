terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Bewusst KEIN Backend: Dieser State ist winzig und bleibt lokal.
}

provider "aws" {
  region = "us-east-1"
}

# Wer bin ich? -> liefert die Account-ID
data "aws_caller_identity" "aktuell" {}

resource "aws_s3_bucket" "state" {
  # Bucket-Namen sind weltweit eindeutig. Mit der Account-ID ist das garantiert.
  bucket = "tfstate-${data.aws_caller_identity.aktuell.account_id}-us-east-1"

  # NUR für die Sandbox: erlaubt das Löschen, auch wenn noch Dateien drin sind.
  # In einer Firma: false + lifecycle { prevent_destroy = true }
  force_destroy = true
}

# Versionierung: Jede Änderung am State bleibt erhalten -> Rückweg bei Fehlern
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Verschlüsselung: Im State können Geheimnisse stehen
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Niemals öffentlich
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.state.bucket
}

