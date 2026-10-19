output "state_bucket_name" {
  description = "Use this as bucket in task-1-ec2-provisioning/backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Use this as dynamodb_table in task-1-ec2-provisioning/backend.hcl."
  value       = aws_dynamodb_table.locks.name
}
