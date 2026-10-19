output "instance_ids" {
  description = "Instance name to instance ID."
  value       = module.ec2_fleet.instance_ids
}

output "instance_private_ips" {
  description = "Instance name to private IP."
  value       = module.ec2_fleet.instance_private_ips
}

output "protected_instance_names" {
  description = "Instances Terraform will refuse to destroy."
  value       = module.ec2_fleet.protected_instance_names
}
