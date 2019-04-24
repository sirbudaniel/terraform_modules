provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

module "vpc" {
  source                  = "../../../../terraform_modules/vpc/vpc_modules"
  cidr                    = "${var.cidr}"
  vpc_tags                = "${var.tags}"
  cidr_generic_pubsubnet  = "${var.generic_pub_subnet}"
  cidr_generic_privsubnet = "${var.generic_priv_subnet}"

  cluster_name            = "${var.cluster_name}"
}
