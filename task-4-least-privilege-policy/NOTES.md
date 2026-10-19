# Task 4 notes

This is the permission review. Every allow is listed. Everything a reviewer would expect to see and will not find is listed with the reason.

`PowerUserAccess` was not used. It is `*` on every non-IAM action. That would let `ci` create buckets, open security groups, and delete the cluster. The brief names three jobs. The policy names those three jobs.

## Permissions granted

### `ecr:GetAuthorizationToken` on `*`

The Docker client calls this before a push. The API does not accept a repository ARN. `Resource "*"` is required by the service, not chosen for convenience. The token is an authorization token for the registry in the account. The following statement is what stops the token from being used to push a second repository.

### On one repository ARN

| Action | Why it is required |
|---|---|
| `ecr:BatchCheckLayerAvailability` | The client asks which layers are already in this repository |
| `ecr:BatchGetImage` | The client reads the image manifest in this repository |
| `ecr:InitiateLayerUpload` | Starts an upload into this repository |
| `ecr:UploadLayerPart` | Sends a part of a layer |
| `ecr:CompleteLayerUpload` | Finishes the layer |
| `ecr:PutImage` | Writes the manifest. This is the push |

These seven actions are the push. They are not granted on `*`.

### `ecs:RegisterTaskDefinition` and `ecs:DescribeTaskDefinition` on `*`

`RegisterTaskDefinition` creates a new revision. AWS does not let you name one service in the resource element. The revision is not deployed until `UpdateService` points the service at it. `DescribeTaskDefinition` lets the pipeline read the revision it just registered so it can pass that ARN to `UpdateService`.

### `ecs:UpdateService` and `ecs:DescribeServices` on one service ARN

`UpdateService` is the deploy. The ARN includes the cluster name and the service name, so a second service in the same cluster is not covered. `DescribeServices` lets the pipeline see whether the deployment reached steady state. It is read-only and scoped to that service.

### `iam:PassRole` on two role ARNs, with a condition

Registering a task definition fails if the caller cannot pass the execution role and the task role. The resources are those two roles only. The condition `iam:PassedToService` equals `ecs-tasks.amazonaws.com` means the roles can be passed to ECS tasks and not to EC2, Lambda, or another service. A `PassRole` without that condition is a privilege escalation. The condition is why this statement is acceptable.

### On the one artifacts bucket

| Action | Resource | Why |
|---|---|---|
| `s3:ListBucket` | bucket ARN | List keys. This action is authorized on the bucket, not on the object |
| `s3:GetBucketLocation` | bucket ARN | The AWS CLI and the SDKs call this before a read. It returns the region |
| `s3:GetObject` | `bucket/*` | Read artifacts. This action is authorized on the object |

That is read-only. There is no write.

## Permissions omitted

### S3

| Omitted | Why |
|---|---|
| `s3:PutObject`, `s3:DeleteObject`, `s3:PutObjectAcl` | The brief says read-only. A pipeline that can write the artifacts bucket can replace a build that a later job trusts |
| `s3:GetObject` on `*` | Would read every bucket the account can see, including the Terraform state bucket if the names were guessed |
| `s3:ListAllMyBuckets` | Not required to read one known bucket, and it discloses every bucket name |
| `s3:GetObjectVersion` | The pipeline reads the current object. Add this only if a command passes a version id |
| `s3:*` | This is the Task 5 bug, applied to a CI user |

### ECR

| Omitted | Why |
|---|---|
| `ecr:DeleteRepository`, `ecr:BatchDeleteImage` | Push does not require delete. Delete lets a bad pipeline remove the image production is running |
| `ecr:CreateRepository`, `ecr:SetRepositoryPolicy` | The repository is an input. A policy change on the repository is an IAM-like grant |
| `ecr:GetDownloadUrlForLayer` | This downloads image layers and is not part of AWS's documented minimum private-repository push policy |
| `ecr:PutImage` on `*` | That is a push to every repository |

### ECS

| Omitted | Why |
|---|---|
| `ecs:CreateService`, `ecs:DeleteService`, `ecs:CreateCluster`, `ecs:DeleteCluster` | The job is to deploy the existing service, not to replace the platform |
| `ecs:RunTask`, `ecs:StartTask` | Those start tasks outside the service. A pipeline could run a task with the passed role and skip the service |
| `ecs:UpdateService` on `*` | Would deploy every service in the account |
| `ecs:RegisterTaskDefinition` scoped to the service | The API rejects that. Documented above. The scope is on `UpdateService` |
| `ecs:TagResource` | Not required when the register call sends no tags. Add it if the pipeline tags revisions, and keep the reason in this file |
| `ecs:ExecuteCommand` | Shell access into a running task. Unrelated to deploy |

### IAM and the rest of the account

| Omitted | Why |
|---|---|
| `iam:CreateUser`, `iam:AttachUserPolicy`, `iam:PutUserPolicy`, `iam:*` | A CI user that can edit IAM can grant itself `PowerUserAccess` |
| `iam:PassRole` on `*` | Would let `ci` pass any role, including an admin role, into a task |
| `iam:PassRole` without `PassedToService` | The same roles could be passed to a different service |
| `ec2:*`, `vpc:*`, `elasticloadbalancing:*` | Not part of push or deploy |
| `logs:CreateLogGroup` | Log groups are created by the execution role at task start, or ahead of time. The CI user does not need them |
| `cloudtrail:StopLogging`, `guardduty:*` | A deploy identity must not be able to turn off detection |

## Why the two `Resource "*"` lines are still least privilege

A reviewer will flag `GetAuthorizationToken` and `RegisterTaskDefinition`. Both are service limitations. The write that matters for ECR is `PutImage` on one repository. The write that matters for ECS is `UpdateService` on one service. Removing the `*` lines makes the pipeline fail. Widening the other lines makes the pipeline an administrator of those services.

## Attachment

The policy is attached to user `ci` only when asked. It is not attached to `group1`. `engine` would inherit a group attachment. The brief gives `engine` and `ci` the same access method, not the same job.
