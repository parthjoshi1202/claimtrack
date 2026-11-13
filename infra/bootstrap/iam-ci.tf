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
  name = "claimtrack-gha-plan"
}

resource "aws_iam_user_policy_attachment" "gha_plan_readonly" {
  user       = aws_iam_user.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy" "gha_plan_state" {
  name   = "claimtrack-gha-plan-state-policy"
  user   = aws_iam_user.gha_plan.name
  policy = data.aws_iam_policy_document.gha_plan_state_access.json
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
}

resource "aws_iam_user_policy_attachment" "gha_deploy_poweruser" {
  user       = aws_iam_user.gha_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_user_policy" "gha_deploy_iam" {
  name   = "claimtrack-gha-deploy-iam-policy"
  user   = aws_iam_user.gha_deploy.name
  policy = data.aws_iam_policy_document.gha_deploy_iam_policy.json
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