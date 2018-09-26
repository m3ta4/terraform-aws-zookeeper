# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A ZOOKEEPER ENSEMBLE IN AWS
# These templates show an example of how to use the zookeeper-ensemble module to deploy Zookeeper in AWS. We deploy an Auto
# Scaling Group (ASG): with a small number of Zookeeper server nodes
# Note that these templates assume that the AMI you provide via the ami_id input variable is built from
# the examples/zookeeper-ami/zookeeper.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

# Terraform 0.9.5 suffered from https://github.com/hashicorp/terraform/issues/14399, which causes this template the
# conditionals in this template to fail.
terraform {
  required_version = ">= 0.9.3, != 0.9.5"
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOMATICALLY LOOK UP THE LATEST PRE-BUILT AMI
# This repo contains a Jenkinsfile that automatically builds and publishes the latest AMI by building the Packer
# template at /examples/zookeeper-ami upon every new release. The Terraform data source below automatically looks up the
# latest AMI so that a simple "terraform apply" will just work without the user needing to manually build an AMI and
# fill in the right value.
#
# !! WARNING !! These exmaple AMIs are meant only convenience when initially testing this repo. Do NOT use these example
# AMIs in a production setting because it is important that you consciously think through the configuration you want
# in your own production AMI.
#
# NOTE: This Terraform data source must return at least one AMI result or the entire template will fail. See
# /_ci/publish-amis-in-new-account.md for more information.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ami" "zookeeper" {
  most_recent = true

  # If we change the AWS Account in which test are run, update this value.
  owners = ["497086895112"] # TrustNet Dev

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "is-public"
    values = ["false"]
  }

  filter {
    name   = "name"
    values = ["venafi-zookeeper-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH ZOOKEEPER SERVER EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Zookeeper
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = "${file("${path.module}/examples/root-example/user-data-exhibitor.sh")}"

  vars {
    bucket = "trustnet-dev-zookeeper-config"
    key    = "trustnet/dev/zookeeper"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY ZOOKEEPER IN THE DEFAULT VPC AND SUBNETS
# Using the default VPC and subnets makes this example easy to run and test, but it means Zookeeper is accessible from the
# public Internet. For a production deployment, we strongly recommend deploying into a custom VPC with private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = "${var.vpc_id == "" ? true : false}"
  id      = "${var.vpc_id}"
}

data "aws_subnet_ids" "private" {
  vpc_id = "${data.aws_vpc.default.id}"
  tags {
    SubnetType = "private"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = "${data.aws_vpc.default.id}"
  tags {
    SubnetType = "public"
  }
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ZOOKEEPER SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "zookeeper_ensemble" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  #source = "git::http://git@gogs.devlab.local/kevin/terraform-aws-zookeeper.git//modules/zookeeper-ensemble?ref=feature/zookeeper-asg-scaling-fails-on-3.4"
  source = "modules/zookeeper-ensemble"

  cluster_name  = "${var.cluster_name}-server"
  cluster_size  = "${var.num_servers}"
  instance_type = "t2.micro"
  spot_price    = "${var.spot_price}"

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = "${var.cluster_tag_key}"
  cluster_tag_value = "${var.cluster_name}"

  ami_id    = "${var.ami_id == "" ? data.aws_ami.zookeeper.image_id : var.ami_id}"
  user_data = "${data.template_file.user_data.rendered}"

  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = "${data.aws_subnet_ids.private.ids}"

  # To make testing easier, we allow Zookeeper and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks            = ["66.205.218.243/32", "10.48.0.0/16"]
  allowed_inbound_security_group_ids = ["${module.zookeeper_ensemble.security_group_id}"]
  allowed_inbound_cidr_blocks        = ["66.205.218.243/32"]
  ssh_key_name                       = "${var.ssh_key_name}"

  zookeeper_config_bucket = "trustnet-dev-zookeeper-config"

  tags = [
    {
      key                 = "Environment"
      value               = "development"
      propagate_at_launch = true
    },
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONNECT THE ZOOKEEPER ENSEMBLE TO AN ALB
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "zookeeper_alb_logs" {
  acl    = "private"
  bucket = "trustnet-dev-zookeeper-alb-logs"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "797873946194"},
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::trustnet-dev-zookeeper-alb-logs/*"
    }
  ]
}
EOF

  versioning {
    enabled = "false"
  }

}

# External UI
resource "aws_lb" "exhibitor" {
  name               = "exhibitor-ui"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${module.zookeeper_ensemble.security_group_id}"]
  subnets            = ["${data.aws_subnet_ids.public.ids}"]

  enable_deletion_protection = false

  access_logs {
    bucket  = "${aws_s3_bucket.zookeeper_alb_logs.bucket}"
    prefix  = "exhibitor-ui-"
    enabled = true
  }
}

resource "aws_alb_target_group" "exhibitor" {
  name_prefix = "exhbtr"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "${data.aws_vpc.default.id}"

  health_check {
    healthy_threshold   = 2
    interval            = 15
    path                = "/exhibitor/v1/cluster/status"
    timeout             = 10
    unhealthy_threshold = 2
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_exhibitor" {
  autoscaling_group_name = "${module.zookeeper_ensemble.asg_name}"
  alb_target_group_arn   = "${aws_alb_target_group.exhibitor.arn}"
}

resource "aws_lb_listener" "exhibitor_ui" {
  load_balancer_arn = "${aws_lb.exhibitor.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.exhibitor.arn}"
  }
}
