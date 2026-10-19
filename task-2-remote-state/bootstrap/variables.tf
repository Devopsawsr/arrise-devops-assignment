variable "region" {
  description = "Region for the state bucket and the lock table."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Leave null to use the default credential chain."
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table that holds the Terraform lock."
  type        = string
  default     = "arrise-terraform-locks"
}
