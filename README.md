# Arrise DevOps assignment

Each task is a separate Terraform root with its own README and NOTES. Start with the task README, not this page.

| Task | Path |
|---|---|
| 1. Five EC2 instances | [task-1-ec2-provisioning](task-1-ec2-provisioning/README.md) |
| 2. Remote state and locking | [task-2-remote-state](task-2-remote-state/README.md) |
| 3. Cross-account IAM | [task-3-cross-account-iam](task-3-cross-account-iam/README.md) |
| 4. CI least-privilege policy | [task-4-least-privilege-policy](task-4-least-privilege-policy/README.md) |
| 5. Broken role fix | [task-5-bug-fix](task-5-bug-fix/README.md) |

Shared assumptions are in [docs/assumptions.md](docs/assumptions.md).

Apply Task 2 before Task 1. Do not apply Task 5 in an account where Task 3 has already created `roleC`.

The account IDs `000000000000` and `111111111111` are the IDs from the brief. Replace them, and every subnet, key name, and bucket name, before an apply.
