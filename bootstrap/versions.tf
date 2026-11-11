terraform {
  # 1.11+ is needed for S3-native state locking (use_lockfile) used in backend.tf.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.primary_region

  # Every resource created through this provider gets these tags.
  default_tags {
    tags = {
      project    = var.project
      env        = var.env
      managed_by = "terraform"
      stack      = "bootstrap"
    }
  }
}
