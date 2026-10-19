module "ec2_fleet" {
  source = "./modules/ec2_fleet"

  name_prefix   = var.name_prefix
  ebs_optimized = var.ebs_optimized
  environment   = var.environment
  owner         = var.owner
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id
  instances     = var.instances
}
