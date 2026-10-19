# Task 5 — Fix the broken role

## 1. Purpose

Show the two defects in the supplied role snippet, why each one fails, and the corrected role. The broken file is `broken.tf.example`. Terraform does not load it. The corrected role is `main.tf`.

Task 3 is the full design. This directory is the isolated fix so the two changes can be read on their own. Do not apply both in the same Account B. They both create `roleC`.

## 2. Requirements covered

| Requirement | Where |
|---|---|
| Issue 1, the trust principal | [NOTES.md](NOTES.md) and `broken.tf.example` |
| Issue 2, `s3:*` on `*` | [NOTES.md](NOTES.md) and `broken.tf.example` |
| Original and corrected configuration | `broken.tf.example` and `main.tf` |
| AWS behavior and the security impact of each | [NOTES.md](NOTES.md) |

## 3. Architecture

`roleC` is created in Account B. Its trust policy allows one principal, `roleB` in Account A. Its identity policy allows `s3:*` on one bucket and the objects in that bucket.

There is no default AWS provider. The only provider is the alias `account_b`, so a resource cannot land in the wrong account by omission.

## 4. Terraform design decisions

The broken snippet is kept as `.example` so a reviewer can diff it against `main.tf` and so `terraform apply` cannot create the broken role by accident.

The corrected principal is built from `var.account_a_id`:

```text
arn:aws:iam::<account A>:role/roleB
```

The corrected resources are:

```text
arn:aws:s3:::<bucket>
arn:aws:s3:::<bucket>/*
```

Both are required. The bucket ARN covers bucket-level actions such as `ListBucket`. The object ARN covers object actions such as `GetObject` and `PutObject`.

## 5. Security considerations

The corrected policy is still `s3:*` on that bucket, including delete. That matches "full access to one bucket". It does not match a read-only bucket. Task 4 is the read-only policy. Do not copy this policy onto user `ci`.

Trusting the role ARN, not the account root, is the whole of the cross-account boundary. NOTES explains what the root principal would have allowed.

## 6. Assumptions

- `roleB` already exists in Account A, or it will be created by Task 3. This root does not create `roleB`.
- The bucket name is the one bucket the role may use. This root does not create the bucket. If the bucket does not exist, `s3:*` still attaches, and the first API call fails until the bucket exists.
- This root is not applied where Task 3 already created `roleC`.

## 7. How to deploy

Prefer Task 3. Use this root only to demonstrate the corrected snippet in an account that does not already have `roleC`.

```bash
cd task-5-bug-fix
cp terraform.tfvars.example terraform.tfvars
```

Set the Account B profile, the Account A id, and the bucket name.

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

1. `terraform validate` succeeds. `broken.tf.example` is not part of the plan.
2. The trust policy principal is `arn:aws:iam::<account A>:role/roleB`.
3. The identity policy resources are the one bucket ARN and that ARN with `/*`.
4. Assume `roleC` using credentials from `roleB`. `s3:ListBucket` on the named bucket succeeds.
5. `s3:ListBucket` on any other bucket is denied.
6. Assume `roleC` using an IAM user named `roleB`, if one were created. The call is denied, because the trust does not list a user.

## 9. Rollback

```bash
terraform destroy
```

That deletes `roleC` and its inline policy. It does not delete `roleB` or the bucket.

## 10. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `AccessDenied` on `AssumeRole` from `roleB` | Account ID in the trust does not match Account A | Set `account_a_id` to the account that owns `roleB` |
| `EntityAlreadyExists` | Task 3 already created `roleC` | Do not apply this root there |
| `ListBucket` denied and `GetObject` allowed, or the reverse | Only one of the two ARNs is present | Keep both the bucket ARN and the object ARN |
| Plan shows the broken principal | `broken.tf.example` was renamed to `.tf` | Rename it back |

## 11. Expected outputs

This root has no outputs. The review artifact is the role:

- Name `roleC` in Account B.
- Trust principal `arn:aws:iam::<account A>:role/roleB`.
- Policy `roleC-s3-access` with `s3:*` on one bucket and its objects.
