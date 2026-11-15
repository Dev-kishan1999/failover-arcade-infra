data "aws_caller_identity" "current" {}

# Created by the bootstrap stack.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  github_oidc_host = "token.actions.githubusercontent.com"
}

# ---------------------------------------------------------------------------
# Container registry
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136:Default AES256 encryption is enough for this project
  name = var.project

  # A tag can never be overwritten, so a deployed tag always means one image.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the 20 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Registry-level setting: every image pushed to a matching repository in the
# primary region is copied to the secondary region. ECR creates the
# destination repository on first replication.
resource "aws_ecr_replication_configuration" "cross_region" {
  replication_configuration {
    rule {
      destination {
        region      = var.secondary_region
        registry_id = local.account_id
      }

      repository_filter {
        filter      = var.project
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Role the application repo's pipeline assumes to push images
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only release tags in the app repo can push.
    condition {
      test     = "StringLike"
      variable = "${local.github_oidc_host}:sub"
      values   = ["repo:${var.app_github_repo}:ref:refs/tags/${var.release_tag_pattern}"]
    }
  }
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "RegistryLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushAndPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role" "ecr_push" {
  name                 = "${var.project}-gha-ecr-push"
  description          = "Lets the app repo's release pipeline push images to ECR"
  assume_role_policy   = data.aws_iam_policy_document.ecr_push_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
