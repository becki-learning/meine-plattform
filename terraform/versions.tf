terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # "Partial Configuration": Der Bucket-Name fehlt absichtlich.
  # Er ist in jeder Sandbox anders und wird von "make" beim init übergeben:
  #   terraform init -backend-config="bucket=..."
  backend "s3" {
    key          = "plattform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Sperrdatei in S3: Zwei Leute können nicht gleichzeitig ändern
  }
}

provider "aws" {
  region = var.region

  # Diese Tags bekommt JEDE Ressource automatisch -> man sieht in AWS sofort, was zu wem gehört
  default_tags {
    tags = {
      Projekt   = var.projekt
      Verwaltet = "terraform"
    }
  }
}
