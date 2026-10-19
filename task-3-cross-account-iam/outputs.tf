output "role_a_arn" {
  value = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  value = aws_iam_role.role_b.arn
}

output "role_c_arn" {
  value = aws_iam_role.role_c.arn
}

output "role_c_bucket" {
  value = aws_s3_bucket.role_c.bucket
}

output "iam_access_key_ids" {
  description = "Assignment-only access key IDs when create_access_keys is enabled."
  value = merge(
    { for name, key in aws_iam_access_key.group1 : name => key.id },
    { for name, key in aws_iam_access_key.group2 : name => key.id },
  )
  sensitive = true
}

output "iam_secret_access_keys" {
  description = "Assignment-only secret keys. Display once and store securely; they are also present in Terraform state."
  value = merge(
    { for name, key in aws_iam_access_key.group1 : name => key.secret },
    { for name, key in aws_iam_access_key.group2 : name => key.secret },
  )
  sensitive = true
}
