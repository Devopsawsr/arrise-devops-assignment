# Task 3 — Cross-account IAM

## 1. Purpose

Create the users, groups, and roles from the brief across two accounts, with the smallest trust that still lets the named people do the job.

Account A (`000000000000` in the brief) holds the users and `roleA` and `roleB`. Account B (`111111111111`) holds `roleC` and the one bucket that role may use.

## 2. Requirements covered

| Requirement | Where |
|---|---|
| `group1`, members `engine` and `ci`, CLI only | `groups.tf` |
| `group2`, two named users, console and CLI | `groups.tf`, default users `jagan` and `priya` |
| `roleA` administrative except IAM | `roles_account_a.tf` |
| `roleB` may only assume `roleC` | `roles_account_a.tf` |
| `roleC` full access to one bucket, trust only `roleB` | `role_c.tf` |
| Why not long-lived keys for `engine` and `ci` | [NOTES.md](NOTES.md) |
| Why not trust the Account A root | [NOTES.md](NOTES.md) |

## 3. Architecture

```text
Account A
  user engine, user ci  --> group1
       group1 policy: sts:GetCallerIdentity only
       no login profile; assignment-only access key when enabled

  user jagan, user priya --> group2
       console login profile, generated password, reset required
       assignment-only access key when enabled
       group2 policy: sts:AssumeRole on roleA and roleB only

  roleA  trust: jagan and priya
         allow * , deny iam:*
  roleB  trust: jagan and priya
         allow sts:AssumeRole on roleC only

Account B
  roleC  trust: arn:aws:iam::ACCOUNT_A:role/roleB
         allow s3:* on one bucket and its objects
  bucket public access block, SSE-S3, versioning, TLS deny
```

A group cannot be a principal in a trust policy. AWS rejects it. The trust lists the two user ARNs. Membership in `group2` is what gives those users `sts:AssumeRole`. Both sides are required. A user who is not in the trust cannot assume the role even if they are in the group. A user who is in the trust cannot call `AssumeRole` unless the group policy allows that role ARN.

## 4. Terraform design decisions

Two provider aliases, `account_a` and `account_b`. There is no default provider. A resource without a provider would be a mistake, so the aliases are explicit.

`aws_iam_user_group_membership` is used. `aws_iam_group_membership` is the older resource and fights with a second membership on the same user.

The current AWS provider does not accept a caller-supplied console password on `aws_iam_user_login_profile`. `password` is computed. The resource sets `password_length` and `password_reset_required`. The generated password is stored in state. Set `create_console_login` to false to skip the login profile. Do not output the password.

`aws_iam_access_key` is optional and disabled by default. The example enables it only to demonstrate the CLI/programmatic access explicitly requested by the brief. The secret is stored in Terraform state, so production should leave it disabled and use temporary credentials.

`roleC`'s ARN is built from the account ID and the role name. `roleB`'s policy can then point at Account B before the role in Account B is read back across providers. The name in both places is `roleC`. If you rename one, change both.

## 5. Security considerations

- `group1` has no console password. Assignment-only access keys can be enabled to demonstrate CLI access. The only group identity policy is `sts:GetCallerIdentity`. Task 4 attaches the pipeline policy to user `ci` alone, so `engine` does not inherit it.
- `group2` is not an administrator group. Admin rights sit on `roleA`, which is an assume-role session and shows up in CloudTrail as the role session.
- `roleA` allows every action and then denies `iam:*`. The brief asks for administrative access except IAM. Organizations, account, and STS calls are not IAM. They remain allowed. That residual is described in NOTES. I did not silently deny them, because that would no longer match the brief.
- `roleB` has one action and one resource: `sts:AssumeRole` on `roleC`.
- `roleC` trusts `role/roleB`, not `root`, and not `user/roleB`.
- The bucket blocks public access, encrypts objects, versions them, and denies non-TLS calls.
- `s3:*` on that one bucket includes delete. The brief asks for full access to one bucket. It does not grant any other bucket.
- External ID is not set. Both sides are our accounts. An external ID matters when a third party is in the trust. Adding a fake one would not change who can assume the role.

## 6. Assumptions

- Two CLI profiles can create IAM and one S3 bucket in the two accounts.
- The account IDs in the example are the placeholders from the brief. Replace them before apply.
- `jagan` and `priya` are the two `group2` names. Change `group2_users` if the names should be different. There must be exactly two.
- This root and Task 5 must not both create `roleC`.

## 7. How to deploy

```bash
cd task-3-cross-account-iam
cp terraform.tfvars.example terraform.tfvars
```

Set the two profiles, the two account IDs, and a globally unique bucket name. Leave `create_console_login` at its default unless you want the users created with no console password.

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
2. In Account A, `engine` and `ci` are in `group1`, have no login profile, and have an access key only when `create_access_keys` is enabled.
3. `jagan` and `priya` are in `group2`.
4. `roleA` trust policy lists those two user ARNs and no account root.
5. `roleA` identity policy has `Allow` on `*` and `Deny` on `iam:*`.
6. `roleB` identity policy has only `sts:AssumeRole` on the `roleC` ARN.
7. In Account B, `roleC` trust has one principal: `arn:aws:iam::<account A>:role/roleB`.
8. `roleC` can list and write its bucket. A second bucket is not in the policy.
9. Assuming `roleC` as `jagan` without going through `roleB` fails.

## 9. Rollback

Remove a user by deleting that name from the variable and applying. `roleC` and the bucket are removed by `terraform destroy` in this root. Destroy Account B resources only when nothing else depends on that bucket.

Do not detach `roleA` by hand and leave the users. The next apply will put the policy back. Change the Terraform and apply.

Set `create_console_login` to false and apply to delete the login profiles. The generated password leaves state with them.

## 10. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `MalformedPolicyDocument` on the trust | A group ARN was used as a principal | Trust the user ARNs. The group policy grants `AssumeRole` |
| Access denied on `AssumeRole` for `roleC` | The caller is the user, not `roleB` | The user assumes `roleB`, then `roleB` assumes `roleC` |
| `EntityAlreadyExists` on `roleC` | Task 5 was applied in this account | Import the role or destroy the Task 5 copy. Do not keep both |
| Console password is not in the plan output | The provider treats it as sensitive state | Read it from state only when issuing the first login, then the user resets it |

## 11. Expected outputs

```text
role_a_arn    = "arn:aws:iam::000000000000:role/roleA"
role_b_arn    = "arn:aws:iam::000000000000:role/roleB"
role_c_arn    = "arn:aws:iam::111111111111:role/roleC"
role_c_bucket = "the-bucket-name"
```

The account IDs change when the tfvars change.
