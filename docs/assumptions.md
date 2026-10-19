# Assumptions

These apply to every task.

- The AWS account IDs in the brief (`000000000000` and `111111111111`) are placeholders. A real apply uses two real accounts and two CLI profiles.
- No private keys, console passwords, or `.tfvars` files are committed. `terraform.tfvars` and `backend.hcl` are gitignored.
- The five EC2 key pairs already exist. This repo does not generate key pairs, because the private key would be stored in state.
- The example instance types (`t3.micro`, `t3.small`, `t3.medium`, `m5.large`, `r5.large`) support EBS optimization. `ebs_optimized` defaults to true. Set it to false if a future type does not support it.
- Root volume types are limited to types AWS accepts for a root disk: `standard`, `gp2`, `gp3`, `io1`, `io2`. `st1` and `sc1` cannot be a root volume, so they are not used.
- Encryption uses the account default EBS key and SSE-S3. A customer-managed KMS key is the production upgrade when the organization requires key custody. It is not hardcoded here because the key ARN is account-specific.
- Each task directory is its own Terraform state. They are not one workspace.
- Task 5 and Task 3 both know how to create a role named `roleC`. Only one of them may be applied in Account B.
- Region defaults to `us-east-1` because that is a valid single-region example. Change `region` in tfvars for another region. The state bucket, lock table, and instances must share the region you choose, except that the bucket name is global.
