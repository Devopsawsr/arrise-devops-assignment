terraform {
  backend "s3" {
    key     = "task1/ec2-fleet/terraform.tfstate"
    encrypt = true
  }
}
