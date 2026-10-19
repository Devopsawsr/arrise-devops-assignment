# Task 2 notes

## What two simultaneous applies do to local state

Local state is a file, `terraform.tfstate`, on one disk. Terraform reads it, calls AWS, then writes the file back. The local backend can lock the file when two processes share the same working directory. It cannot provide a shared lock between separate copies on different laptops or CI runners.

Two people, or two CI jobs, each with a separate copy of that file:

1. Both read the same snapshot.
2. Both decide the same resources are missing.
3. Both create them.
4. Both write a state file. The write that finishes last wins. The earlier write is gone.

The loser file still describes real AWS resources. Those resources are now outside Terraform. The next plan does not know their IDs, so it tries to create them again and collides, or it never updates them. That is state corruption. It is not a theoretical race. It is two writers and no lock.

Other local-state failures that are not the race:

- The laptop disk fills or the process is killed during the write. The JSON is truncated. The next plan cannot parse it. There is no older version unless the operator copied the file by hand.
- The file is emailed, copied to a laptop that is later lost, or committed by mistake. It contains resource IDs and any secret that was in configuration.
- There is no shared history. One operator's apply is invisible to the other until they exchange the file, and by then the file is already stale.

## How the lock changes that

The S3 backend stores one state object. Before writing, Terraform puts an item in DynamoDB with hash key `LockID`. The value is the state path. DynamoDB accepts the put only if that key is absent, so the second apply cannot take the lock.

The second apply stops with `Error acquiring the state lock` and the lock ID. It does not create a second copy of the infrastructure and it does not overwrite the state object. When the first apply finishes, it deletes the item. The second apply can then read the new state and plan against reality.

The hash key must be named `LockID` and it must be a string. Terraform writes that attribute. A table with a different key name does not lock anything. The apply appears to work and the race is back.

## Disaster recovery

Versioning is the recovery tool for the state object. A bad apply that wrote a bad state can be rolled back by copying the previous object version over the current key. Do that while nobody holds the lock.

Losing the DynamoDB table does not lose the state. The state is in S3. Recreate the table with the same name and `LockID` as a string hash key. Until it exists, do not run apply, because an S3 backend without its lock table fails closed only when the table is configured and missing. If someone removes `dynamodb_table` to "get unblocked", the race returns.

The bucket has `prevent_destroy`. That stops Terraform from deleting the inventory during a casual destroy. It does not stop a principal with `s3:DeleteBucket` in the console. The bucket policy and public access block reduce exposure. They are not a backup in another region.

I did not add cross-region replication. Replication needs a destination bucket, a replication IAM role, and a decision about which region is the failover region. Inventing those would look complete and would be wrong for an account I do not control. Versioning in the primary region covers the failure this assignment can demonstrate: a bad state write. Region loss is a follow-up, and NOTES is the place that says so.

Point-in-time recovery on the lock table was skipped for the same class of reason. The table holds a lock row for the length of an apply. Recreating the table restores the function. PITR would matter if the table stored something other than the lock.

`terraform force-unlock` is the dangerous escape hatch. Use it only when the process that took the lock is dead. Using it while that process is still writing lets the second writer through. That is the local-state race again, with an extra step.

## Backend security

State is an inventory of the account. Anyone who can `s3:GetObject` on that key can read it. The bucket is private, encrypted, and TLS-only. Access should be limited to the Terraform role. This bootstrap does not attach a broad read policy to a user.

`encrypt = true` in the backend block means Terraform will not upload state if encryption is off. The bucket default encryption is a second control, for anything else written to the bucket.

The first bootstrap apply is local because the bucket does not exist yet. That local file is the remaining risk. After apply, migrate it with the example backend in `bootstrap/backend.tf.example` under the key `task2/bootstrap/terraform.tfstate`. Do not point the bootstrap and Task 1 at the same key. They would overwrite each other.

## What I did not choose

Terraform Cloud or an HCP backend was not used. The brief asks for S3 and DynamoDB.

A native S3 lock (`use_lockfile`) was not used as the only lock. The brief names DynamoDB, and the table key must be `LockID`. The DynamoDB lock is the one this task implements.

Current Terraform documentation marks DynamoDB-based S3 locking as deprecated and recommends native S3 locking with `use_lockfile = true`. DynamoDB remains here because the assignment explicitly requires it. For a new production implementation, I would use native S3 locking or configure both temporarily during a controlled migration.

I did not commit `backend.hcl`. It contains the real bucket name and is an account-specific input. The example file shows the shape.
