resource "aws_s3_bucket" "role_c" {
  provider = aws.account_b
  bucket   = var.role_c_bucket_name
}

resource "aws_s3_bucket_public_access_block" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "role_c_bucket_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.role_c.arn,
      "${aws_s3_bucket.role_c.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "role_c_bucket_tls" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id
  policy   = data.aws_iam_policy_document.role_c_bucket_tls.json
}

data "aws_iam_policy_document" "role_c_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      # Referencing the resource creates the required dependency: roleB must
      # exist in Account A before Account B validates this trust principal.
      identifiers = [aws_iam_role.role_b.arn]
    }
  }
}

data "aws_iam_policy_document" "role_c_s3" {
  statement {
    sid     = "OneBucket"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.role_c.arn,
      "${aws_s3_bucket.role_c.arn}/*",
    ]
  }
}

resource "aws_iam_role" "role_c" {
  provider           = aws.account_b
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.role_c_trust.json

  tags = {
    Name = "roleC"
  }
}

resource "aws_iam_role_policy" "role_c" {
  provider = aws.account_b
  name     = "roleC-one-bucket"
  role     = aws_iam_role.role_c.id
  policy   = data.aws_iam_policy_document.role_c_s3.json
}
