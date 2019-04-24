## input parameters for module

variable "vpc_id" {
  description = "VPC_ID of the vpc where the eks cluster will be created"
  type        = "string"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = "string"
}

variable "ssh_key_name" {
  description = "SSH key for accessing nodes"
  type        = "string"
}

variable "public_cidr" {
  description = "Public subnet cidrs"
  type        = "list"
}

variable "private_cidr" {
  description = "Private subnet cidrs"
  type        = "list"
}

variable "instance_type" {
  description = "EKS worker nodes instance type"
  type        = "string"
  default     = "c4.4xlarge"
}

variable "worker_volume_size" {
  description = "Worker nodes volume size"
  type        = "string"
  default     = 120
}

variable "autoscaling_limits" {
  description = "EKS workers autoscaling group limits"
  type        = "map"

  default {
    min     = 3
    max     = 30
    desired = 3
  }
}


data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = ["${var.vpc_id}"]
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

locals {
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "SubnetType"                                = "Utility"
    "clusterName"                               = "${var.cluster_name}"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal_elb"           = "1"
    "SubnetType"                                = "Private"
    "clusterName"                               = "${var.cluster_name}"
  }

  common_tags = {
    "tag1" = "val1"
    "tag2" = "val2"
  }

  worker_ami = {
    "us-west-2" = "ami-0f54a2f7d2e9c88b3"
    "us-east-1" = "ami-0a0b913ef3249b655"
    "us-east-2" = "ami-0958a76db2d150238"
    "eu-west-1" = "ami-00c3b2d35bddd4f5c"
  }
}

### Workers Config
resource "aws_launch_configuration" "workers" {
  name_prefix                 = "lc-${var.cluster_name}"
  image_id                    = "${local.worker_ami[data.aws_region.current.name]}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.worker_profile.name}"
  security_groups             = ["${aws_security_group.eks_workers.id}"]
  associate_public_ip_address = false
  key_name                    = "${var.ssh_key_name}"

  root_block_device {
    # device_name           = "/dev/xvda"
    volume_type           = "gp2"
    delete_on_termination = true
    volume_size           = "${var.worker_volume_size}"
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<EOF
  set -o xtrace
  /etc/eks/bootstrap.sh ${var.cluster_name}
EOF
}

resource "aws_autoscaling_group" "workers" {
  name                 = "EksWorkers-${var.cluster_name}"
  launch_configuration = "${aws_launch_configuration.workers.id}"
  min_size             = "${var.autoscaling_limits["min"]}"
  max_size             = "${var.autoscaling_limits["max"]}"
  desired_capacity     = "${var.autoscaling_limits["min"]}"
  vpc_zone_identifier  = ["${aws_subnet.public_subnets.*.id}", "${aws_subnet.private_subnets.*.id}"]

  tags = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}-instances-Node"
      propagate_at_launch = true
    },
    {
      key                 = "kubernetes.io/cluster/${var.cluster_name}"
      value               = "owned"
      propagate_at_launch = true
    },
    {
      key                 = "clusterName"
      value               = "${var.cluster_name}"
      propagate_at_launch = true
    },
  ]
}

### EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.cluster_name}"
  role_arn = "${aws_iam_role.eks_role.arn}"

  vpc_config {
    subnet_ids         = ["${aws_subnet.private_subnets.*.id}"]
    security_group_ids = ["${aws_security_group.eks_controlplane.id}"]
  }
}
