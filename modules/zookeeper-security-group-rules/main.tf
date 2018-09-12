# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP RULES THAT CONTROL WHAT TRAFFIC CAN GO IN AND OUT OF A CONSUL CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_zookeeper_client_inbound" {
  count       = "${length(var.allowed_inbound_cidr_blocks) >= 1 ? 1 : 0}"
  type        = "ingress"
  from_port   = "${var.zookeeper_client_port}"
  to_port     = "${var.zookeeper_client_port}"
  protocol    = "tcp"
  cidr_blocks = ["${var.allowed_inbound_cidr_blocks}"]

  security_group_id = "${var.security_group_id}"
}

resource "aws_security_group_rule" "allow_zookeeper_peer_inbound" {
  count       = "${length(var.allowed_inbound_cidr_blocks) >= 1 ? 1 : 0}"
  type        = "ingress"
  from_port   = "${var.zookeeper_peer_port}"
  to_port     = "${var.zookeeper_peer_port}"
  protocol    = "tcp"
  cidr_blocks = ["${var.allowed_inbound_cidr_blocks}"]

  security_group_id = "${var.security_group_id}"
}

resource "aws_security_group_rule" "allow_zookeeper_elect_tcp_inbound" {
  count       = "${length(var.allowed_inbound_cidr_blocks) >= 1 ? 1 : 0}"
  type        = "ingress"
  from_port   = "${var.zookeeper_elect_port}"
  to_port     = "${var.zookeeper_elect_port}"
  protocol    = "tcp"
  cidr_blocks = ["${var.allowed_inbound_cidr_blocks}"]

  security_group_id = "${var.security_group_id}"
}

resource "aws_security_group_rule" "allow_zookeeper_client_inbound_from_security_group_ids" {
  count                    = "${length(var.allowed_inbound_security_group_ids)}"
  type                     = "ingress"
  from_port                = "${var.zookeeper_client_port}"
  to_port                  = "${var.zookeeper_client_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allowed_inbound_security_group_ids, count.index)}"

  security_group_id = "${var.security_group_id}"
}

resource "aws_security_group_rule" "allow_zookeeper_peer_inbound_from_security_group_ids" {
  count                    = "${length(var.allowed_inbound_security_group_ids)}"
  type                     = "ingress"
  from_port                = "${var.zookeeper_peer_port}"
  to_port                  = "${var.zookeeper_peer_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allowed_inbound_security_group_ids, count.index)}"

  security_group_id = "${var.security_group_id}"
}

resource "aws_security_group_rule" "allow_zookeeper_elect_tcp_inbound_from_security_group_ids" {
  count                    = "${length(var.allowed_inbound_security_group_ids)}"
  type                     = "ingress"
  from_port                = "${var.zookeeper_elect_port}"
  to_port                  = "${var.zookeeper_elect_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allowed_inbound_security_group_ids, count.index)}"

  security_group_id = "${var.security_group_id}"
}

