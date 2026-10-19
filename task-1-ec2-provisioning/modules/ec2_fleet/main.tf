data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  protected = {
    for name, inst in var.instances : name => inst if inst.protect_from_destroy
  }
  standard = {
    for name, inst in var.instances : name => inst if !inst.protect_from_destroy
  }
}

resource "terraform_data" "fleet_contract" {
  input = keys(var.instances)

  lifecycle {
    precondition {
      condition     = length(var.instances) == 5
      error_message = "The fleet module expects exactly 5 instances from the one input map."
    }

    precondition {
      condition     = length(local.protected) == 1
      error_message = "Mark exactly one instance with protect_from_destroy."
    }

    precondition {
      condition = anytrue([
        for inst in values(var.instances) : contains(["io1", "io2"], inst.root_volume_type)
      ])
      error_message = "At least one root volume must be io1 or io2."
    }
  }
}

resource "aws_security_group" "fleet" {
  name        = "${var.name_prefix}-ec2-fleet"
  description = "No inbound access. Instances stay on their private addresses."
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.name_prefix}-ec2-fleet"
    Environment = var.environment
    Owner       = var.owner
  }

  depends_on = [terraform_data.fleet_contract]
}

resource "aws_instance" "standard" {
  for_each = local.standard

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = each.value.instance_type
  subnet_id                   = coalesce(each.value.subnet_id, var.subnet_id)
  key_name                    = each.value.key_name
  vpc_security_group_ids      = [aws_security_group.fleet.id]
  associate_public_ip_address = false
  ebs_optimized               = var.ebs_optimized

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? each.value.root_volume_iops : null
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = each.key
      Environment = var.environment
      Owner       = var.owner
    }
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_instance" "protected" {
  for_each = local.protected

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = each.value.instance_type
  subnet_id                   = coalesce(each.value.subnet_id, var.subnet_id)
  key_name                    = each.value.key_name
  vpc_security_group_ids      = [aws_security_group.fleet.id]
  associate_public_ip_address = false
  ebs_optimized               = var.ebs_optimized

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? each.value.root_volume_iops : null
    encrypted             = true
    delete_on_termination = false

    tags = {
      Name        = each.key
      Environment = var.environment
      Owner       = var.owner
    }
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}
