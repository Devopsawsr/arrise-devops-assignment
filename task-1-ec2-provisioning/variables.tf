variable "region" {
  description = "Region for the five instances."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Leave null to use the default credential chain."
  type        = string
  default     = null
}

variable "ebs_optimized" {
  description = "Enable EBS optimization on every instance."
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix for the security group name so it does not collide in a shared VPC."
  type        = string
  default     = "arrise"
}

variable "environment" {
  description = "Value of the Environment tag on every instance."
  type        = string
}

variable "owner" {
  description = "Value of the Owner tag on every instance."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the instance security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for all five instances."
  type        = string
}

variable "instances" {
  description = "All five instances, keyed by Name. One map drives the module."
  type = map(object({
    instance_type        = string
    root_volume_type     = string
    root_volume_size     = number
    root_volume_iops     = optional(number)
    key_name             = string
    subnet_id            = optional(string)
    protect_from_destroy = optional(bool, false)
  }))

  validation {
    condition     = length(var.instances) == 5
    error_message = "Provide exactly 5 instances."
  }

  validation {
    condition = length([
      for name, inst in var.instances : name if inst.protect_from_destroy
    ]) == 1
    error_message = "Set protect_from_destroy = true on exactly one instance."
  }

  validation {
    condition = anytrue([
      for inst in values(var.instances) : contains(["io1", "io2"], inst.root_volume_type)
    ])
    error_message = "At least one instance must use an io1 or io2 root volume."
  }

  validation {
    condition = (
      length(distinct([for inst in values(var.instances) : inst.instance_type])) == 5 &&
      length(distinct([for inst in values(var.instances) : inst.root_volume_type])) == 5 &&
      length(distinct([for inst in values(var.instances) : inst.root_volume_size])) == 5 &&
      length(distinct([for inst in values(var.instances) : inst.key_name])) == 5
    )
    error_message = "Instance type, root volume type, root volume size, and key pair must differ on every instance."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) :
      !contains(["io1", "io2"], inst.root_volume_type) || coalesce(inst.root_volume_iops, 0) >= 100
    ])
    error_message = "io1 and io2 root volumes need root_volume_iops of at least 100."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) :
      contains(["standard", "gp2", "gp3", "io1", "io2"], inst.root_volume_type)
    ])
    error_message = "A root volume must be standard, gp2, gp3, io1, or io2. st1 and sc1 cannot be a root disk."
  }

  validation {
    condition = alltrue([
      for name, inst in var.instances :
      length(name) > 0 && length(inst.instance_type) > 0 && length(inst.key_name) > 0 && inst.root_volume_size >= 8
    ])
    error_message = "Every instance needs a name, an instance type, a key pair, and a root volume of at least 8 GiB."
  }
}
