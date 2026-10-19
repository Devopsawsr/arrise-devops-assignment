# Deployment order

Apply in this order when the accounts are real.

1. Task 2 bootstrap. Creates the state bucket and the lock table. The first apply uses local state.
2. Task 1. `terraform init -backend-config=backend.hcl`, then plan and apply. This is the only root that should hold the EC2 state.
3. Optional. Migrate the Task 2 bootstrap state into the bucket with `bootstrap/backend.tf.example`, using the key `task2/bootstrap/terraform.tfstate`.
4. Task 3. Two accounts. Creates users, groups, `roleA`, `roleB`, `roleC`, and the one bucket.
5. Task 4. Set `attach_to_ci_user` to true only after user `ci` exists. Apply the CI policy.
6. Task 5. Do not apply it in an account where Task 3 created `roleC`. Read `broken.tf.example` against `main.tf` and NOTES.

`terraform.tfvars` and `backend.hcl` stay uncommitted. The example files are the templates.

Destroy is the reverse, with two exceptions. Task 1 will not destroy `data-store` until `protect_from_destroy` is turned off in a reviewed change. Task 2 will not destroy the state bucket or the lock table while `prevent_destroy` is set. Leave both until the state they protect has been retired on purpose.
