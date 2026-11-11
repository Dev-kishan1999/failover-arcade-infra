output "account_id" {
  description = "AWS account the bootstrap stack was applied to."
  value       = local.account_id
}

output "state_bucket" {
  description = "S3 bucket that stores Terraform state for every stack."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_region" {
  description = "Region of the state bucket."
  value       = var.primary_region
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN variable in the GitHub repo."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN variable in the GitHub repo."
  value       = aws_iam_role.apply.arn
}

output "backend_config" {
  description = "Paste into backend.tf, then run: terraform init -migrate-state"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tfstate.bucket}"
        key          = "bootstrap/terraform.tfstate"
        region       = "${var.primary_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
