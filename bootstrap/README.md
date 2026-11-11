# Bootstrap stack

Applied once, from a laptop, by an administrator. It creates the foundation
that lets every later stack be deployed by GitHub Actions:

| Resource | Purpose |
|---|---|
| S3 bucket `failover-arcade-tfstate-<account-id>` | Remote Terraform state, versioned, encrypted, TLS-only, S3-native locking |
| IAM OIDC provider for GitHub | Lets GitHub Actions get short-lived AWS credentials, no stored keys |
| Role `failover-arcade-gha-plan` | Read-only, assumable from pull request workflows |
| Role `failover-arcade-gha-apply` | Admin, assumable only from the `main` branch |
| AWS Budget | Email alerts at 50%, 80%, 100% actual and 100% forecast |

## Prerequisites

- Terraform 1.11 or newer, AWS CLI v2, GitHub CLI (`gh`)
- An AWS account with IAM Identity Center enabled and a user that has an
  administrator permission set. Enabling Identity Center and securing the root
  user with MFA are one-time account-owner tasks done before this stack.
- An empty GitHub repo for the infrastructure code

## Runbook

### 1. Sign in from the CLI

```bash
aws configure sso --profile arcade-admin   # one time: start URL, region, account, role
aws sso login --profile arcade-admin
export AWS_PROFILE=arcade-admin
aws sts get-caller-identity                # confirm the account ID is the one you expect
```

### 2. First apply (local state)

The state bucket does not exist yet, so the first run keeps state locally.

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # then edit it
terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

### 3. Move the bootstrap state into the bucket it just created

```bash
terraform output -raw backend_config > backend.tf
terraform init -migrate-state      # answer "yes" to copy local state to S3
rm -f terraform.tfstate terraform.tfstate.backup
terraform plan                     # must report: No changes
```

### 4. Give the role ARNs to GitHub

Repository variables, not secrets: a role ARN is not sensitive, and the OIDC
trust policy is what protects the role.

```bash
gh variable set AWS_PLAN_ROLE_ARN  --body "$(terraform output -raw plan_role_arn)"
gh variable set AWS_APPLY_ROLE_ARN --body "$(terraform output -raw apply_role_arn)"
gh variable set AWS_REGION         --body "$(terraform output -raw state_bucket_region)"
gh variable set TF_STATE_BUCKET    --body "$(terraform output -raw state_bucket)"
```

### 5. Verify

```bash
BUCKET=$(terraform output -raw state_bucket)

aws s3api get-bucket-versioning --bucket "$BUCKET"          # Status: Enabled
aws s3api get-public-access-block --bucket "$BUCKET"        # all four true
aws s3 ls "s3://$BUCKET/bootstrap/"                         # terraform.tfstate
aws iam list-open-id-connect-providers                      # GitHub provider listed
aws iam get-role --role-name failover-arcade-gha-plan  --query 'Role.Arn'
aws iam get-role --role-name failover-arcade-gha-apply --query 'Role.Arn'
aws budgets describe-budgets \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --query 'Budgets[].BudgetName'
```

Each budget subscriber also receives a confirmation email from AWS.

## How other stacks use this

Every later stack points at the same bucket with its own key:

```hcl
terraform {
  backend "s3" {
    bucket       = "failover-arcade-tfstate-<account-id>"
    key          = "regional/ca-central-1/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Workflows authenticate like this:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.AWS_PLAN_ROLE_ARN }}
      aws-region: ${{ vars.AWS_REGION }}
```

## Notes

- **Trust conditions are exact.** The plan role only accepts `pull_request`
  events and the apply role only accepts the `main` branch. If a workflow job
  uses a GitHub `environment:`, the token's subject changes to
  `repo:<owner>/<repo>:environment:<name>` and the trust policy must be
  updated to match.
- **The apply role has AdministratorAccess.** That is deliberate for now,
  because the stacks create IAM roles. Replace it with a scoped policy once
  the full list of services is settled.
- **The state bucket is protected by `prevent_destroy`.** Tearing down the
  project means destroying the other stacks first and removing that lifecycle
  block last.
- **.gitignore** should include `terraform.tfvars`, `*.tfplan`, `.terraform/`
  and `*.tfstate*`. Commit `.terraform.lock.hcl`.
