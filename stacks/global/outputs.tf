output "ecr_repository_url" {
  description = "Push and pull images at this URL in the primary region."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_url_secondary" {
  description = "URL of the replicated repository in the secondary region."
  value       = "${local.account_id}.dkr.ecr.${var.secondary_region}.amazonaws.com/${aws_ecr_repository.app.name}"
}

output "ecr_push_role_arn" {
  description = "Set as AWS_ECR_PUSH_ROLE_ARN in the application repo."
  value       = aws_iam_role.ecr_push.arn
}
