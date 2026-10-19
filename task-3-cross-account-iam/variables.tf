variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_a_profile" {
  description = "CLI profile for Account A."
  type        = string
}

variable "account_b_profile" {
  description = "CLI profile for Account B."
  type        = string
}

variable "account_a_id" {
  description = "Account A. The brief uses 000000000000."
  type        = string
  default     = "000000000000"
}

variable "account_b_id" {
  description = "Account B. The brief uses 111111111111."
  type        = string
  default     = "111111111111"
}

variable "group2_users" {
  description = "Named users who may use the console and the CLI."
  type        = list(string)
  default     = ["jagan", "priya"]

  validation {
    condition     = length(var.group2_users) == 2 && length(distinct(var.group2_users)) == 2
    error_message = "group2 needs exactly two different users."
  }
}

variable "create_console_login" {
  description = "Create a console login for each group2 user. The provider generates the password and stores it in state. Set false to leave console sign-in disabled."
  type        = bool
  default     = true
}

variable "create_access_keys" {
  description = "Create assignment-only long-lived keys for CLI/programmatic access. Keep false in production and use temporary credentials instead."
  type        = bool
  default     = false
}

variable "role_c_bucket_name" {
  description = "The one bucket roleC can use. Must be globally unique."
  type        = string
}
