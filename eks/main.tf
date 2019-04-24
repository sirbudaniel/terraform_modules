provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}


data "aws_vpcs" "current_vpc" {
  tags {
    clusterName = "${var.cluster_name}"
  }
}

resource "null_resource" "check_subnets_equals" {
  count                                                                              = "${length(var.private_cidr) == length(var.public_cidr) ? 0 : 1}"
  "We should have the same number of private and public subnets for the EKS clsuter" = true
}

locals {
  vpc_id = "${length(data.aws_vpcs.current_vpc.ids) == 1 ? data.aws_vpcs.current_vpc.ids[0]: "ERROR: There should be exactly one VPC with the tag clusterName=var.cluster_name"}"
}

module "eks" {
  source       = "../../../../terraform_modules/eks/eks_modules"
  vpc_id       = "${local.vpc_id}"
  cluster_name = "${var.cluster_name}"
  ssh_key_name = "${var.ssh_key_name}"
  public_cidr  = "${var.public_cidr}"
  private_cidr = "${var.private_cidr}"
}
