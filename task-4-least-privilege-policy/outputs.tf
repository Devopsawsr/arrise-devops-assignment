output "ci_policy_json" {
  description = "The rendered least-privilege policy."
  value       = local.policy_json
}

output "ci_policy_arn" {
  value = aws_iam_policy.ci_pipeline.arn
}
