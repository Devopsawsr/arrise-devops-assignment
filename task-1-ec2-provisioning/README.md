# Task 1 — Multi-instance EC2 provisioning

## 1. Purpose

Create five EC2 instances from one Terraform variable. The instances differ in type, root volume type, root volume size, and key pair. One of them is protected from `terraform destroy`.

The module is `modules/ec2_fleet`. This directory is the root module that calls it.

## 2. Requirements covered

| Requirement | Where |
|---|---|
| A module, not five handwritten resource blocks | `modules/ec2_fleet/main.tf` uses `for_each` |
| One input structure for all five | `variables.tf` variable `instances` |
| Different type, volume type, volume size, and key pair | validation on `instances` |
| At least one `io1` or `io2` volume | validation, and `worker` / `data-store` in the example |
| Tags `Name`, `Environment`, `Owner` | both instance resources |
| Lifecycle protection on one chosen instance | `aws_instance.protected` |
| Why that instance | [NOTES.md](NOTES.md) |
| Map of name to instance ID | output `instance_ids` |
| Map of name to private IP | output `instance_private_ips` |

## 3. Architecture

```text
variables.instances (one map, five entries)
        |
        v
modules/ec2_fleet
        |
        +-- local.standard   -> aws_instance.standard    (four instances)
        +-- local.protected  -> aws_instance.protected   (data-store only)
        +-- aws_security_group.fleet   (no inbound)
        +-- data.aws_ami.amazon_linux  (Amazon Linux 2023)
```

State for this root is remote. The backend block is `backend.tf`. The bucket and lock table are created by Task 2 before this root is initialized.

Instances have no public IP. They are reached from inside the VPC. The security group allows outbound HTTPS only.

## 4. Terraform design decisions

`for_each` is keyed by the instance name. That name is the `Name` tag, the output map key, and the state address. Reordering the map does not rename instances. `count` would, so it was not used.

`prevent_destroy` must be a literal. Terraform rejects a variable there. The module still has one input map. A local splits it. Four names go to `aws_instance.standard`. The one name with `protect_from_destroy = true` goes to `aws_instance.protected`, and only that resource has the lifecycle block. Writing five `aws_instance` blocks would violate the brief.

`io1` and `io2` require `iops`. Other volume types omit `iops`, because sending it to `gp2` or `standard` makes the API reject the volume.

The AMI is a data source, not a hardcoded ID. Hardcoded AMI IDs expire and differ by region.

Key pairs are referenced by name. Generating them in Terraform would put private key material in state.

## 5. Security considerations

- No inbound rule. SSH is not open to the internet. Use Session Manager or a bastion that is outside this assignment.
- `associate_public_ip_address` is false.
- IMDSv2 is required (`http_tokens = required`).
- Root volumes are encrypted.
- The protected instance sets `delete_on_termination` to false, so a manual terminate does not drop the disk immediately.
- No secrets are in this directory.

`prevent_destroy` does not stop the AWS console, CLI, or an API call from terminating the instance. It only stops Terraform.

## 6. Assumptions

- The VPC and subnet already exist.
- Five key pairs already exist, one per instance, and the names match `key_name`.
- The example types support EBS optimization. See [docs/assumptions.md](../docs/assumptions.md).
- Task 2 has been applied, and `backend.hcl` names that bucket.

## 7. How to deploy

From `task-2-remote-state/bootstrap`, apply the bucket and table first. Then:

```bash
cd task-1-ec2-provisioning
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
```

Edit both files. `terraform.tfvars` needs real `vpc_id`, `subnet_id`, and key names. `backend.hcl` needs the bucket name and the lock table name from the Task 2 outputs.

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Syntax only, with no AWS account:

```bash
terraform init -backend=false
terraform validate
```

## 8. Validation steps

1. `terraform validate` succeeds.
2. `terraform plan` shows five instances to add, one security group, and no public IP.
3. After apply, `terraform output instance_ids` is a map of five names to IDs.
4. `terraform output instance_private_ips` is a map of five names to private addresses.
5. `terraform output protected_instance_names` contains `data-store`.
6. `terraform destroy` stops and names `aws_instance.protected`. The other plan may still want to delete the unprotected instances. Do not confirm that destroy in a real environment unless that is intended.

## 9. Rollback

Unprotected instances: remove their key from `instances` and apply, or run a targeted destroy.

```bash
terraform destroy -target='module.ec2_fleet.aws_instance.standard["web"]'
```

`data-store` will not be destroyed while `prevent_destroy` is set. To retire it on purpose:

1. Take a snapshot of the root volume if the data matters.
2. Set `protect_from_destroy = false` for `data-store` in a reviewed change.
3. Apply that change so the lifecycle block no longer covers it.
4. Remove the key and apply again.

If an apply was wrong and state is the problem, restore the previous `terraform.tfstate` object from the versioned state bucket. Do that only when no other apply is running. See Task 2.

## 10. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `InvalidKeyPair.NotFound` | `key_name` does not exist in this region | Create the key pair, or change the name |
| `VolumeIopsLimit` or iops required | `io1` or `io2` without `root_volume_iops` | Set iops to at least 100 |
| Backend init error | Bucket or table does not exist | Apply Task 2, then init again |
| `Error acquiring the state lock` | Another apply holds the lock | Wait, or see Task 2 before any force-unlock |
| `prevent_destroy` on destroy | Expected for `data-store` | Follow the rollback steps above |
| Plan wants a public IP | A subnet setting auto-assigns public IPs | This module still sets `associate_public_ip_address = false` |

## 11. Expected outputs

```text
instance_ids = {
  api        = "i-..."
  data-store = "i-..."
  edge       = "i-..."
  web        = "i-..."
  worker     = "i-..."
}

instance_private_ips = {
  api        = "10.x.x.x"
  data-store = "10.x.x.x"
  edge       = "10.x.x.x"
  web        = "10.x.x.x"
  worker     = "10.x.x.x"
}

protected_instance_names = ["data-store"]
```
