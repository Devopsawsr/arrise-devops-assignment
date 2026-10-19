# Task 5 notes

The snippet fails for two independent reasons. Fixing only one of them still leaves a broken or unsafe role. The original is `broken.tf.example`. The correction is `main.tf`.

## Issue 1 — the trust principal

### Original

```hcl
identifiers = ["arn:aws:iam::000000000000:user/roleB"]
```

### Corrected

```hcl
identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
```

### Why it failed

`roleB` is an IAM role. The ARN of a role contains `:role/`. The ARN of a user contains `:user/`. These are different principals. STS compares the caller to the trust policy. When `roleB` calls `AssumeRole`, the caller ARN is `arn:aws:iam::ACCOUNT_A:role/roleB`. That string does not equal `arn:aws:iam::ACCOUNT_A:user/roleB`. The call is denied.

Creating the role succeeds. The failure is at assume time, which is why a plan that only checks that the role exists looks fine.

### AWS behavior

The principal element is not a name search. AWS does not look up "something called roleB". It matches the ARN. A user and a role can share a name and still be different principals. Trusting the user ARN would start working only if someone created a user named `roleB` and that user called `AssumeRole`. The role would still be denied. That is a worse outcome than a clean deny, because the wrong identity would be the one that worked.

### Security implications

If the trust is changed the other way, to `arn:aws:iam::ACCOUNT_A:root`, the assume starts working for `roleB` and for every other principal in Account A that has permission to assume `roleC`. The path through `roleB` stops being a boundary. A user, a CI key, or another role in Account A can reach the bucket directly. The corrected trust allows one hop, from `roleB` only.

## Issue 2 — `s3:*` on every resource

### Original

```hcl
Action   = "s3:*"
Resource = "*"
```

### Corrected

```hcl
Action = "s3:*"
Resource = [
  "arn:aws:s3:::${var.bucket_name}",
  "arn:aws:s3:::${var.bucket_name}/*",
]
```

### Why it failed

The brief says full access to one named bucket. `Resource "*"` is every bucket the credentials can reach, and `s3:*` includes `GetObject`, `PutObject`, `DeleteObject`, and `DeleteBucket`. The role is not scoped. This is not an API error. The policy is valid. It is the wrong authorization. IAM will allow it.

### AWS behavior

S3 authorizes some actions on the bucket ARN and some on the object ARN.

- `s3:ListBucket`, `s3:GetBucketLocation`, and `s3:DeleteBucket` are bucket actions. They match `arn:aws:s3:::name`.
- `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` are object actions. They match `arn:aws:s3:::name/*`.

A policy that lists only the bucket ARN allows list and denies get. A policy that lists only `/*` allows get and denies list. `Resource "*"` matches both, which is why the broken policy "works" and also why it works on every bucket in the account. The fix lists both ARNs for the one bucket.

`Resource "*"` combined with `s3:*` also matches buckets the role was never meant to see, including a Terraform state bucket in the same account.

### Security implications

With the original policy, anyone who can assume `roleC` can read and delete objects in every bucket in Account B. That includes backups, logs, and state. The corrected policy still allows delete, because the brief asks for full access, and it allows that only on the named bucket. A delete of any other bucket is denied.

Leaving `Resource "*"` and only changing the principal would make the trust correct and the data exposure unchanged. Both lines had to change.

## What was not a third bug

The snippet does not set a provider alias. In a single-account root that is harmless. In this assignment Account B is a different account, so the corrected root uses `provider = aws.account_b` on both resources. That is part of making the fix safe to apply. It is not a third defect in the JSON the brief showed.

External ID was not added. The caller is our role, not a vendor. See Task 3 NOTES.
