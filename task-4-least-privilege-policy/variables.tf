variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "CLI profile for the account that owns user ci."
  type        = string
  default     = null
}

variable "account_id" {
  description = "Account that owns the pipeline resources."
  type        = string
}

variable "ecr_repository_name" {
  description = "The one ECR repository ci may push to."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Cluster that contains the one ECS service."
  type        = string
}

variable "ecs_service_name" {
  description = "The one ECS service ci may deploy."
  type        = string
}

variable "task_execution_role_name" {
  description = "Execution role the task definition uses."
  type        = string
}

variable "task_role_name" {
  description = "Task role the task definition uses."
  type        = string
}

variable "artifacts_bucket_name" {
  description = "Artifacts bucket ci may read and must not write."
  type        = string
}

variable "attach_to_ci_user" {
  description = "Attach the policy to the existing ci user."
  type        = bool
  default     = true
}
