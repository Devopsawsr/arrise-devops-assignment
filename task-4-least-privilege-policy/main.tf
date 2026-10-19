locals {
  policy_json = templatefile("${path.module}/policy.tftpl", {
    region                   = var.region
    account_id               = var.account_id
    ecr_repository_name      = var.ecr_repository_name
    ecs_cluster_name         = var.ecs_cluster_name
    ecs_service_name         = var.ecs_service_name
    task_execution_role_name = var.task_execution_role_name
    task_role_name           = var.task_role_name
    artifacts_bucket_name    = var.artifacts_bucket_name
  })
}

resource "aws_iam_policy" "ci_pipeline" {
  name        = "ci-pipeline"
  description = "Push one ECR repository, deploy one ECS service, read one artifacts bucket."
  policy      = local.policy_json
}

data "aws_iam_user" "ci" {
  count     = var.attach_to_ci_user ? 1 : 0
  user_name = "ci"
}

resource "aws_iam_user_policy_attachment" "ci" {
  count      = var.attach_to_ci_user ? 1 : 0
  user       = data.aws_iam_user.ci[0].user_name
  policy_arn = aws_iam_policy.ci_pipeline.arn
}
