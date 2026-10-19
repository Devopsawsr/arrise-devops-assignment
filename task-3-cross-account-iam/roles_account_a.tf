data "aws_iam_policy_document" "group2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        for user in aws_iam_user.group2 : user.arn
      ]
    }
  }
}

data "aws_iam_policy_document" "role_a_permissions" {
  statement {
    sid       = "AllServices"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyIam"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "role_a" {
  provider           = aws.account_a
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.group2_trust.json

  tags = {
    Name = "roleA"
  }
}

resource "aws_iam_role_policy" "role_a" {
  provider = aws.account_a
  name     = "roleA-admin-except-iam"
  role     = aws_iam_role.role_a.id
  policy   = data.aws_iam_policy_document.role_a_permissions.json
}

data "aws_iam_policy_document" "role_b_permissions" {
  statement {
    sid       = "AssumeRoleCOnly"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.role_c_arn]
  }
}

resource "aws_iam_role" "role_b" {
  provider           = aws.account_a
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.group2_trust.json

  tags = {
    Name = "roleB"
  }
}

resource "aws_iam_role_policy" "role_b" {
  provider = aws.account_a
  name     = "roleB-assume-roleC"
  role     = aws_iam_role.role_b.id
  policy   = data.aws_iam_policy_document.role_b_permissions.json
}
