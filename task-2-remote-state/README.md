# Task 2 — Remote state and locking

## 1. Purpose

Create the S3 bucket and DynamoDB table that hold Terraform state and the apply lock. The backend block that uses them is applied from Task 1, because that is the state being locked. A copy of that block is in `backend.tf.example` so this directory shows the contract. It is not a `.tf` file here, so `terraform init` in this folder does not create an empty stack.

## 2. Requirements covered

| Requirement | Where |
|---|---|
| S3 remote state | `bootstrap/main.tf` creates the bucket. Task 1 `backend.tf` uses it |
| DynamoDB lock, hash key `LockID`, type string | `aws_dynamodb_table.locks` |
| Why local state fails when two applies run | [NOTES.md](NOTES.md) |
| How the lock stops that | [NOTES.md](NOTES.md) |

## 3. Architecture

```text
bootstrap/          local state, one time
  aws_s3_bucket.state
  versioning, SSE-S3, public access block, TLS deny
  aws_dynamodb_table.locks   hash key LockID (S)

task-1-ec2-provisioning/backend.tf
  backend "s3" {
    key     = "task1/ec2-fleet/terraform.tfstate"
    encrypt = true
  }
  bucket, region, and dynamodb_table come from backend.hcl at init
```

The bootstrap cannot store its own state in the bucket it is creating until that bucket exists. The first apply is local. After the bucket exists, the bootstrap state can be migrated into it under a different key. That migration block is `bootstrap/backend.tf.example`. It is not active, so the first apply still works.

## 4. Terraform design decisions

One backend block, in Task 1. A second live `backend.tf` in this directory would drift from the first.

Bucket name, region, and `dynamodb_table` are partial backend configuration in `backend.hcl`. The bucket name must be globally unique. The table name must match `lock_table_name` from this bootstrap. `encrypt` and `key` stay in the committed block.

`PAY_PER_REQUEST` is used on the lock table. A lock row exists only during apply. Provisioned capacity would sit idle and can throttle a lock write if it is set to zero.

`prevent_destroy` is on the bucket and the table. A later `terraform destroy` in the bootstrap root will refuse to delete the state. That is the point.

Cross-region replication is not configured. It needs a second region, a replication role, and a destination bucket the brief does not name. Versioning in this region is the recovery path that this task can actually stand up. The omission is recorded in NOTES.

## 5. Security considerations

- Public access block is on for ACLs and policies.
- A bucket policy denies `s3:*` when `aws:SecureTransport` is false.
- Default encryption is SSE-S3 (AES256). The backend also sets `encrypt = true`, so Terraform refuses to write an unencrypted state object.
- The lock table has server-side encryption.
- `force_destroy` is false. An empty-bucket delete still cannot pass `prevent_destroy`.
- State contains resource IDs and, if a later change is careless, can contain secrets. Task 3 stores a generated console password in its state when console login is enabled. Treat that state as confidential.
- The bootstrap state file on disk is also confidential. Do not commit it. `.gitignore` already excludes `*.tfstate`.

## 6. Assumptions

- The caller can create an S3 bucket and a DynamoDB table in the chosen region.
- The bucket name is not taken.
- Task 1 will pass the same table name (`arrise-terraform-locks` unless you change both).
- One region is enough for this assignment. A second region is a follow-up, not a silent default.

## 7. How to deploy

```bash
cd task-2-remote-state/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Set `state_bucket_name` to a name you own. Then:

```bash
terraform init
terraform plan
terraform apply
```

Copy the bucket name into `task-1-ec2-provisioning/backend.hcl` and init Task 1 with `-backend-config=backend.hcl`.

To move this bootstrap state into the bucket after the first apply, copy `backend.tf.example` to `backend.tf`, set the bucket name, and run `terraform init -migrate-state`. Do that only after the bucket and table exist.

Syntax check without AWS:

```bash
terraform init -backend=false
terraform validate
```

## 8. Validation steps

1. `terraform validate` succeeds.
2. After apply, the bucket shows versioning Enabled, encryption AES256, and all four public-access settings true.
3. The bucket policy contains `DenyInsecureTransport`.
4. The DynamoDB table hash key is `LockID` and the type is `S`.
5. Start a Task 1 apply, then start a second one. The second waits or fails with `Error acquiring the state lock`. It must not write a second state file.
6. `terraform destroy` on this root stops because of `prevent_destroy`.

## 9. Rollback

The lock table can be recreated. State cannot.

If the table is deleted by hand, Terraform has not lost the EC2 state. Create a new table with the same name and hash key `LockID` of type string, or point `dynamodb_table` at the new name and re-init.

If a bad apply wrote a bad state object, restore the previous version of `task1/ec2-fleet/terraform.tfstate` from the bucket. Confirm no apply is running first. `terraform force-unlock` only when the lock holder is dead. A force-unlock while an apply is running lets a second apply write the same state.

Do not empty the bucket to "start again" unless the Task 1 infrastructure has also been removed by a reviewed destroy. The state object is the inventory.

## 10. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `BucketAlreadyExists` | The name is taken globally | Pick another name |
| `Error acquiring the state lock` | A real apply holds the lock, or a crashed apply left it | Read the lock ID in the error. If the process is alive, wait. If it is dead, `force-unlock` that ID |
| Init asks for the bucket | `backend.hcl` is missing | Copy the example and set the name |
| Destroy wants to delete the bucket and then refuses | `prevent_destroy` | Leave the bucket. Remove it from state only if you are abandoning this root on purpose |
| Bootstrap state is only on one laptop | First apply is local by necessity | Migrate it after the bucket exists |

## 11. Expected outputs

```text
state_bucket_name = "the-name-you-chose"
lock_table_name   = "arrise-terraform-locks"
```
