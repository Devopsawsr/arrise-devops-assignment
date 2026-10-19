variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_b_profile" {
  description = "CLI profile for Account B, where roleC must exist."
  type        = string
}

variable "account_a_id" {
  description = "Account that owns roleB."
  type        = string
  default     = "000000000000"
}

variable "bucket_name" {
  description = "The one bucket roleC may use."
  type        = string
}
