# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.8 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.9.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE INSTANCES FOR A ZOOKEEPER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_instance" "zookeeper" {
  count                       = "${var.cluster_size}"
  ami                         = "${var.ami_id}"
  associate_public_ip_address = "${var.associate_public_ip_address}"
  ebs_optimized               = "${var.root_volume_ebs_optimized}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.ssh_key_name}"
  subnet_id                   = "${element(var.subnet_ids, count.index)}"
  user_data                   = "${var.user_data}"
  vpc_security_group_ids      = ["${concat(list(aws_security_group.zookeeper.id), var.additional_security_group_ids)}"]
  root_block_device {
    volume_size = "${var.root_volume_size}"
    volume_type = "${var.root_volume_type}"
    #iops        = "${var.root_volume_iops}" This needs a condition if io1
  }
  tags {
    Name      = "${var.cluster_name}${format("%02d", count.index + 1)}"
  }
}
# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT REQUESTS CAN GO IN AND OUT OF EACH EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "zookeeper" {
  name_prefix = "${var.cluster_name}"
  description = "Security group for the ${var.cluster_name} cluster."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(map("Name", var.cluster_name), var.security_group_tags)}"
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  count       = "${length(var.allowed_ssh_cidr_blocks) >= 1 ? 1 : 0}"
  type        = "ingress"
  from_port   = "${var.ssh_port}"
  to_port     = "${var.ssh_port}"
  protocol    = "tcp"
  cidr_blocks = ["${var.allowed_ssh_cidr_blocks}"]

  security_group_id = "${aws_security_group.zookeeper.id}"
}

resource "aws_security_group_rule" "allow_ssh_inbound_from_security_group_ids" {
  count                    = "${length(var.allowed_ssh_security_group_ids)}"
  type                     = "ingress"
  from_port                = "${var.ssh_port}"
  to_port                  = "${var.ssh_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allowed_ssh_security_group_ids, count.index)}"

  security_group_id = "${aws_security_group.zookeeper.id}"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.zookeeper.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE ZOOKEEPER-SPECIFIC INBOUND/OUTBOUND RULES COME FROM THE ZOOKEEPER-SECURITY-GROUP-RULES MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "security_group_rules" {
  source = "../zookeeper-security-group-rules"

  security_group_id                  = "${aws_security_group.zookeeper.id}"
  allowed_inbound_cidr_blocks        = ["${var.allowed_inbound_cidr_blocks}"]
  allowed_inbound_security_group_ids = ["${var.allowed_inbound_security_group_ids}"]

  zookeeper_client_port = "${var.zookeeper_client_port}"
  zookeeper_peer_port   = "${var.zookeeper_peer_port}"
  zookeeper_elect_port  = "${var.zookeeper_elect_port}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE DNS RECORDS FOR THE ZOOKEEPER SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "zookeeper_server" {
  count   = "${var.cluster_size}"
  zone_id = "${var.zone_id}"
  name    = "zookeeper-${format("%02d", count.index + 1)}.${var.domain}"
  type    = "A"
  ttl     = "60"
  records = ["${element(aws_instance.zookeeper.*.private_ip, count.index)}"]
}

resource "aws_route53_record" "zookeeper" {
  zone_id = "${var.zone_id}"
  name    = "zookeeper.${var.domain}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.zookeeper.*.private_ip}"]
}

