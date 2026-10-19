# ec2_fleet

Module used only by the Task 1 root in this directory's parent.

One map creates every instance. `prevent_destroy` cannot be read from a variable, so the module splits that map into `aws_instance.standard` and `aws_instance.protected`. Only the protected resource has the lifecycle block.

Do not call this module from a second root. A second call creates a second fleet and a second security group.
