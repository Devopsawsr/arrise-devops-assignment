variable "ebs_optimized" {
  description = "Enable EBS optimization. The example instance types all support it."
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for names this module creates."
  type        = string
}

variable "environment" {
  description = "Environment tag."
  type        = string
}

variable "owner" {
  description = "Owner tag."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet shared by the fleet."
  type        = string
}

variable "instances" {
  description = "Fleet definition. The root variable is the single source."
  type = map(object({
    instance_type        = string
    root_volume_type     = string
    root_volume_size     = number
    root_volume_iops     = optional(number)
    key_name             = string
    subnet_id            = optional(string)
    protect_from_destroy = optional(bool, false)
  }))
}
