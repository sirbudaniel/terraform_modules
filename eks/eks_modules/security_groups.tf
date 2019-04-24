resource "aws_security_group" "eks_controlplane" {
  name        = "eks-ControlPlane-${var.cluster_name}"
  description = "eks ControlPlane security group"
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(local.common_tags, map(
    "clusterName", "${var.cluster_name}"
  ))}"
}

resource "aws_security_group" "eks_workers" {
  name        = "eks-workers-${var.cluster_name}"
  description = "eks Workers security group"
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(local.common_tags, map(
    "clusterName", "${var.cluster_name}",
    "kubernetes.io/cluster/${var.cluster_name}", "owned"
  ))}"
}

resource "aws_security_group_rule" "NodeSecurityGroupIngress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.eks_workers.id}"
  security_group_id        = "${aws_security_group.eks_workers.id}"
  description              = "Allow node to communicate with each other"
}

resource "aws_security_group_rule" "NodeSecurityGroupFromControlPlaneIngress" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.eks_controlplane.id}"
  security_group_id        = "${aws_security_group.eks_workers.id}"
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
}

resource "aws_security_group_rule" "ControlPlaneEgressToNodeSecurityGroup" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.eks_workers.id}"
  security_group_id        = "${aws_security_group.eks_controlplane.id}"
  description              = "Allow the cluster control plane to communicate with worker Kubelet and pods"
}

resource "aws_security_group_rule" "NodeSecurityGroupFromControlPlaneOn443Ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.eks_controlplane.id}"
  security_group_id        = "${aws_security_group.eks_workers.id}"
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
}

resource "aws_security_group_rule" "ControlPlaneEgressToNodeSecurityGroupOn443" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.eks_workers.id}"
  security_group_id        = "${aws_security_group.eks_controlplane.id}"
  description              = "Allow the cluster control plane to communicate with pods running extension API servers on port 443"
}

resource "aws_security_group_rule" "ClusterControlPlaneSecurityGroupIngress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.eks_workers.id}"
  security_group_id        = "${aws_security_group.eks_controlplane.id}"
  description              = "Allow pods to communicate with the cluster API Server"
}
