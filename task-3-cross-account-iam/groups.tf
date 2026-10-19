locals {
  group1_users = ["engine", "ci"]
  role_c_arn   = "arn:aws:iam::${var.account_b_id}:role/roleC"
  role_b_arn   = "arn:aws:iam::${var.account_a_id}:role/roleB"
}

resource "aws_iam_user" "group1" {
  provider = aws.account_a
  for_each = toset(local.group1_users)
  name     = each.key
}

# The assignment explicitly asks for CLI/programmatic access. Long-lived IAM
# user keys are created only when enabled for the exercise. In production,
# prefer temporary credentials from IAM Identity Center or workload OIDC.
resource "aws_iam_access_key" "group1" {
  provider = aws.account_a
  for_each = var.create_access_keys ? aws_iam_user.group1 : {}
  user     = each.value.name
}

resource "aws_iam_group" "group1" {
  provider = aws.account_a
  name     = "group1"
}

resource "aws_iam_user_group_membership" "group1" {
  provider = aws.account_a
  for_each = aws_iam_user.group1
  user     = each.value.name
  groups   = [aws_iam_group.group1.name]
}

resource "aws_iam_group_policy" "group1_cli_only" {
  provider = aws.account_a
  name     = "group1-cli-identity-only"
  group    = aws_iam_group.group1.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "CliIdentityOnly"
      Effect   = "Allow"
      Action   = ["sts:GetCallerIdentity"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_user" "group2" {
  provider = aws.account_a
  for_each = toset(var.group2_users)
  name     = each.key
}

resource "aws_iam_access_key" "group2" {
  provider = aws.account_a
  for_each = var.create_access_keys ? aws_iam_user.group2 : {}
  user     = each.value.name
}

resource "aws_iam_group" "group2" {
  provider = aws.account_a
  name     = "group2"
}

resource "aws_iam_user_group_membership" "group2" {
  provider = aws.account_a
  for_each = aws_iam_user.group2
  user     = each.value.name
  groups   = [aws_iam_group.group2.name]
}

resource "aws_iam_user_login_profile" "group2" {
  provider                = aws.account_a
  for_each                = var.create_console_login ? aws_iam_user.group2 : {}
  user                    = each.value.name
  password_length         = 20
  password_reset_required = true
}

data "aws_iam_policy_document" "group2_assume" {
  statement {
    sid     = "AssumeAccountRoles"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      aws_iam_role.role_a.arn,
      aws_iam_role.role_b.arn,
    ]
  }
}

resource "aws_iam_group_policy" "group2_assume" {
  provider = aws.account_a
  name     = "group2-assume-roles"
  group    = aws_iam_group.group2.name
  policy   = data.aws_iam_policy_document.group2_assume.json
}
