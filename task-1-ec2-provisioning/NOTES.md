# Task 1 notes

## Which instance is protected, and why

I protected `data-store`.

It is the only `io2` instance, with a 100 GB root volume and `delete_on_termination = false`. In this fleet it is the one that holds data. The other four are `edge`, `web`, `api`, and `worker`. They are replaceable. Losing them means a new instance and a new root disk. Losing `data-store` means losing the only high-IOPS volume.

`prevent_destroy` is set on `aws_instance.protected` only. `terraform destroy` and an apply that would delete that instance both stop. I did not set it on the other four, because a blanket lock makes a normal replacement require a code change every time.

## Why this implementation, and what I did not choose

Five separate `aws_instance` blocks would meet the lifecycle rule and fail the brief. The brief says one input and no five hardcoded blocks.

`count` over a list was rejected. Inserting an item in the middle renumbers every later instance and Terraform wants to destroy them. `for_each` keyed by name keeps each address stable.

A single `aws_instance` with `for_each` over all five cannot set `prevent_destroy` on only one of them. The lifecycle block is part of the resource, and the value must be known in the configuration, not taken from the map. Splitting the same map into `local.standard` and `local.protected` keeps one input and puts the literal `prevent_destroy = true` only on the protected resource. Exactly one entry must set `protect_from_destroy = true`. A variable validation enforces that.

I did not protect every instance. That is safer against accidents and worse to operate. A reviewer who wants all five locked can set the flag on one resource that uses `for_each` for the whole map. That no longer matches "one specific instance".

## Security and operations

The protection is a Terraform guard, not an AWS guard. The console can still terminate `data-store`. If that matters, add a Service Control Policy or an IAM deny on `ec2:TerminateInstances` for that instance ID. That is outside this module because the instance ID does not exist until after the first apply.

`worker` uses `io1` and `data-store` uses `io2`, so the "at least one io1 or io2" rule is met even if someone changes one of them. The five volume types in the example are the five types AWS allows on a root volume. `st1` and `sc1` were not used because they cannot be a root disk. `standard` is previous-generation magnetic storage. It is here so all five root types differ, not because I would pick it for a new production disk. A production fleet that does not need five different types should use `gp3` for the general nodes and `io2` only for the data node.

No public IP and no inbound security group rule means these instances are not an internet entry point. Operations access belongs on Session Manager, which needs an instance profile this brief did not ask for. I did not attach an empty instance profile just to look complete.
