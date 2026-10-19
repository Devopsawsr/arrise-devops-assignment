# Task 4 — Least-privilege CI policy

## 1. Purpose

Replace a broad managed policy such as `PowerUserAccess` with one customer managed policy for user `ci`. The policy can push one ECR repository, register a task definition, update one ECS service, and read one artifacts bucket.

## 2. Requirements covered

| Requirement | Where |
|---|---|
| Custom policy, not `PowerUserAccess` | `policy.tftpl`, `aws_iam_policy.ci_pipeline` |
| Push Docker to one ECR repository | ECR statements |
| Deploy a new task definition to one ECS service | `RegisterTaskDefinition` and `UpdateService` |
| Read-only on one artifacts bucket | `ListBucket`, `GetBucketLocation`, `GetObject` |
| Why each granted action exists | [NOTES.md](NOTES.md) |
| Why the omitted actions are omitted | [NOTES.md](NOTES.md) |

## 3. Architecture

The policy is a template so the repository, cluster, service, role names, and bucket are variables. The rendered JSON is the policy document. Attachment to user `ci` is optional (`attach_to_ci_user`) so this root can be reviewed before Task 3 has created the user.

The policy is attached to the user, not to `group1`. `engine` is in that group and must not receive this policy.

## 4. Terraform design decisions

`templatefile` keeps the JSON readable and stops a string-built policy from drifting. The AWS provider is not asked to create the ECR repository, the ECS service, or the bucket. Those are inputs. This root grants access to them. Creating them here would expand the assignment into a platform stack and would hide the IAM review.

`iam:PassRole` is limited to the two task roles and to `ecs-tasks.amazonaws.com`. Without the condition, `ci` could pass those roles to another AWS service that accepts `PassRole`.

## 5. Security considerations

`ecr:GetAuthorizationToken` and `ecs:RegisterTaskDefinition` cannot be bound to one ARN. AWS requires `Resource "*"`. The repository limit is on the push actions. The service limit is on `UpdateService`. A registered task definition that is never attached to the named service does not deploy. That is the control AWS actually provides.

The policy does not allow `s3:PutObject`, `s3:DeleteObject`, `ecr:DeleteRepository`, `ecs:DeleteService`, `ecs:RunTask`, or any IAM administration. The full list is in NOTES.

The ECR statement follows AWS's documented repository-scoped image-push permissions. `GetDownloadUrlForLayer` is intentionally omitted because it downloads image layers and is not included in the documented minimum push policy.

## 6. Assumptions

- The ECR repository, ECS cluster, ECS service, both task roles, and the artifacts bucket already exist.
- The pipeline does not tag the task definition on register. `ecs:TagResource` is not included. Add it only if the pipeline sends tags.
- The pipeline reads the current object, not an older version id. `s3:GetObjectVersion` is not included.
- User `ci` exists when `attach_to_ci_user` is true. The example tfvars sets it to false so validate and plan do not require the user.

## 7. How to deploy

```bash
cd task-4-least-privilege-policy
cp terraform.tfvars.example terraform.tfvars
```

Set the account, repository, cluster, service, both role names, and the bucket. Set `attach_to_ci_user` to true only after Task 3 has created user `ci`.

```bash
terraform init
terraform plan
terraform apply
```

Syntax only:

```bash
terraform init -backend=false
terraform validate
```

## 8. Validation steps

1. `terraform validate` succeeds.
2. `terraform output ci_policy_json` contains one ECR repository ARN, one ECS service ARN, two role ARNs, and one bucket.
3. The JSON has no `s3:PutObject`, no `s3:DeleteObject`, and no `ecs:DeleteService`.
4. With the policy attached, `docker push` to that repository succeeds.
5. Push to a second repository is denied.
6. `UpdateService` on the named service succeeds.
7. `UpdateService` on another service is denied.
8. `aws s3 cp` from the artifacts bucket succeeds. `aws s3 cp` to that bucket is denied.
9. `iam:CreateUser` as `ci` is denied.

## 9. Rollback

```bash
terraform destroy
```

That deletes the customer managed policy and the attachment. It does not delete user `ci`, the repository, the service, or the bucket.

To keep the policy and stop using it, set `attach_to_ci_user` to false and apply. The policy remains for inspection and the user no longer has it.

## 10. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `AccessDenied` on `GetAuthorizationToken` | The `*` statement was removed | Put it back. AWS does not allow a repository ARN on that action |
| `AccessDenied` on `PassRole` | The task definition names a third role | Add that role to the `PassRole` resource list, or change the task definition |
| `AccessDenied` on `TagResource` | The pipeline sends tags | Add `ecs:TagResource` on `*` and document why |
| User `ci` not found | Task 3 was not applied, or attach is true too early | Set `attach_to_ci_user` to false, or create the user first |
| Layer upload denied | One of the documented upload actions is missing | Compare the active policy with `policy.tftpl` |

## 11. Expected outputs

`ci_policy_arn` is the ARN of `ci-pipeline`.

`ci_policy_json` is the rendered policy. The repository, service, roles, and bucket in it match the tfvars.
