locals {
  generic_pub_subnet_az_number = "${length(split(":",var.cidr_generic_pubsubnet ))  > 1 ?
                                    element(split(":", var.cidr_generic_pubsubnet), 1) : "0"}"

  generic_priv_subnet_az_number = "${length(split(":",var.cidr_generic_privsubnet ))  > 1 ?
                                     element(split(":", var.cidr_generic_privsubnet), 1) : "0"}"

  common_tags = "${map("clusterName", var.cluster_name)}"
}

resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr}"
  tags       = "${merge(var.vpc_tags, local.common_tags)}"
}

resource "aws_internet_gateway" "InternetGateway" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags   = "${local.common_tags}"
}

resource "aws_eip" "natGwEip" {
  vpc  = true
  tags = "${local.common_tags}"
}

resource "aws_nat_gateway" "natGw" {
  allocation_id = "${aws_eip.natGwEip.id}"
  subnet_id = "${aws_subnet.generic_pub.id}"
}

resource "aws_subnet" "generic_pub" {
  cidr_block = "${element(split(":", var.cidr_generic_pubsubnet), 0)}"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.az_list.names[local.generic_pub_subnet_az_number]}"
  tags = "${local.common_tags}"
}

resource "aws_route_table_association" "generic_pub_subnet_association" {
  route_table_id = "${aws_route_table.generic_pub_route_table.id}"
  subnet_id      = "${aws_subnet.generic_pub.id}"
}

resource "aws_subnet" "generic_priv" {
  cidr_block = "${element(split(":", var.cidr_generic_privsubnet), 0)}"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.az_list.names[local.generic_priv_subnet_az_number]}"
  tags = "${local.common_tags}"
}

resource "aws_route_table_association" "generic_priv_subnet_association" {
  route_table_id = "${aws_route_table.generic_priv_route_table.id}"
  subnet_id      = "${aws_subnet.generic_priv.id}"
}

resource "aws_route_table" "generic_pub_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.InternetGateway.id}"
  }

  tags = "${local.common_tags}"
}

resource "aws_route_table" "generic_priv_route_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.natGw.id}"
  }
}
