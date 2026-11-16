# 1. GHA Plan User (Pull Requests Only - ReadOnly + State Lock)
data "aws_iam_policy_document" "gha_plan_state_access" {
  statement {
    sid       = "StateBucketAccess"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid       = "StateReadAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  statement {
    sid    = "StateLockAccess"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*.tflock"]
  }
}

resource "aws_iam_user" "gha_plan" {
  #checkov:skip=CKV_AWS_273:Account SCP blocks OIDC/SAML providers; scoped IAM user with 90-day key rotation preserves $20 spend cap.
  name = "claimtrack-gha-plan"
}

resource "aws_iam_user_policy_attachment" "gha_plan_readonly" {
  #checkov:skip=CKV_AWS_40:Single-purpose CI service user; policy attached directly for explicit least-privilege auditability.
  user       = aws_iam_user.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy" "gha_plan_state" {
  name   = "claimtrack-gha-plan-state-policy"
  user   = aws_iam_user.gha_plan.name
  policy = data.aws_iam_policy_document.gha_plan_state_access.json
  #checkov:skip=CKV_AWS_40:Single-purpose CI service user; inline policy restricts S3 writes strictly to *.tflock lock files.
}

# 2. GHA Deploy User (Main Branch Only - PowerUser + Scoped IAM)
data "aws_iam_policy_document" "gha_deploy_iam_policy" {
  statement {
    sid    = "ManageClaimtrackRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/claimtrack-*"]
  }

  statement {
    sid       = "PassRoleToEcsOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/claimtrack-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_user" "gha_deploy" {
  name = "claimtrack-gha-deploy"
  #checkov:skip=CKV_AWS_273:Account SCP blocks OIDC/SAML providers; scoped IAM user with 90-day key rotation preserves $20 spend cap.
}

resource "aws_iam_user_policy_attachment" "gha_deploy_poweruser" {
  user       = aws_iam_user.gha_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  #checkov:skip=CKV_AWS_40:Single-purpose CI service user; policy attached directly for explicit least-privilege auditability.
}

resource "aws_iam_user_policy" "gha_deploy_iam" {
  name   = "claimtrack-gha-deploy-iam-policy"
  user   = aws_iam_user.gha_deploy.name
  policy = data.aws_iam_policy_document.gha_deploy_iam_policy.json
  #checkov:skip=CKV_AWS_40:Single-purpose CI service user; inline policy scopes IAM role management to claimtrack-* and ECS PassRole.
}

# 3. Outputs
output "gha_plan_user_name" {
  description = "IAM user name for GitHub Actions PR planning"
  value       = aws_iam_user.gha_plan.name
}

output "gha_deploy_user_name" {
  description = "IAM user name for GitHub Actions deployment"
  value       = aws_iam_user.gha_deploy.name
}