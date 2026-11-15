terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bucket, key and region are passed by the pipeline with -backend-config.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      project    = var.project
      env        = var.env
      managed_by = "terraform"
      stack      = "global"
    }
  }
}
