resource "aws_subnet" "public_subnets" {
  vpc_id            = "${var.vpc_id}"
  cidr_block        = "${var.public_cidr[count.index]}"
  count             = "${length(var.private_cidr)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = "${merge(local.public_subnet_tags, local.common_tags, map(
    "Network", "EKS public subnet in az ${element(data.aws_availability_zones.available.names,count.index)}"
  ))}"
}

resource "aws_subnet" "private_subnets" {
  vpc_id            = "${var.vpc_id}"
  cidr_block        = "${var.private_cidr[count.index]}"
  count             = "${length(var.private_cidr)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = "${merge(local.private_subnet_tags, local.common_tags, map(
    "Network", "EKS private subnet in az ${element(data.aws_availability_zones.available.names,count.index)}"
  ))}"
}

resource "aws_eip" "nat_gateway_eip" {
  vpc   = true
  count = "${length(var.private_cidr)}"

  tags = "${merge(local.common_tags, map(
    "clusterName", "${var.cluster_name}"
  ))}"
}

resource "aws_nat_gateway" "private_ng" {
  allocation_id = "${element(aws_eip.nat_gateway_eip.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public_subnets.*.id, count.index)}"
  count         = "${length(var.private_cidr)}"

  tags = "${merge(local.common_tags, map(
    "clusterName", "${var.cluster_name}"
  ))}"
}

resource "aws_route_table" "private_route_table" {
  vpc_id = "${var.vpc_id}"
  count  = "${length(var.private_cidr)}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.private_ng.*.id, count.index)}"
  }

  tags = "${merge(local.common_tags, map(
    "clusterName", "${var.cluster_name}"
  ))}"
}

resource "aws_route_table_association" "private_route_table" {
  subnet_id      = "${element(aws_subnet.private_subnets.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_route_table.*.id, count.index)}"
  count          = "${length(var.private_cidr)}"
}

resource "aws_route_table" "public_route_table" {
  vpc_id = "${var.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table_association" "public_route_table" {
  subnet_id      = "${element(aws_subnet.public_subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_route_table.id}"
  count          = "${length(var.public_cidr)}"
}
