output "instance_ids" {
  description = "Instance name to instance ID."
  value = merge(
    { for name, inst in aws_instance.standard : name => inst.id },
    { for name, inst in aws_instance.protected : name => inst.id },
  )
}

output "instance_private_ips" {
  description = "Instance name to private IP."
  value = merge(
    { for name, inst in aws_instance.standard : name => inst.private_ip },
    { for name, inst in aws_instance.protected : name => inst.private_ip },
  )
}

output "protected_instance_names" {
  description = "Instances Terraform will refuse to destroy."
  value       = keys(aws_instance.protected)
}
