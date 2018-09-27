# ---------------------------------------------------------------------------------------------------------------------
# THESE TEMPLATES REQUIRE TERRAFORM VERSION 0.8 AND ABOVE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.9.3"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN AUTO SCALING GROUP (ASG) FOR ZOOKEEPER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "autoscaling_group" {
  name_prefix = "${var.cluster_name}"

  launch_configuration = "${aws_launch_configuration.launch_configuration.name}"

  availability_zones  = ["${var.availability_zones}"]
  vpc_zone_identifier = ["${var.subnet_ids}"]

  # Run a fixed number of instances in the ASG
  min_size             = "${var.cluster_size}"
  max_size             = "${var.cluster_size}"
  desired_capacity     = "${var.cluster_size}"
  termination_policies = ["${var.termination_policies}"]

  health_check_type         = "${var.health_check_type}"
  health_check_grace_period = "${var.health_check_grace_period}"
  wait_for_capacity_timeout = "${var.wait_for_capacity_timeout}"

  tags = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}"
      propagate_at_launch = true
    },
    {
      key                 = "${var.cluster_tag_key}"
      value               = "${var.cluster_tag_value}"
      propagate_at_launch = true
    },
    {
      key                 = "DomainMeta"
      value               = "Z3JP3QB1DTH1TW:zookeeper.dev.trustnet.aws"
      propagate_at_launch = true
    },
    "${var.tags}"
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE LAUNCH CONFIGURATION TO DEFINE WHAT RUNS ON EACH INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "launch_configuration" {
  name_prefix   = "${var.cluster_name}-"
  image_id      = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  user_data     = "${var.user_data}"
  spot_price    = "${var.spot_price}"

  iam_instance_profile        = "${aws_iam_instance_profile.instance_profile.name}"
  key_name                    = "${var.ssh_key_name}"
  security_groups             = ["${concat(list(aws_security_group.lc_security_group.id), var.additional_security_group_ids)}"]
  placement_tenancy           = "${var.tenancy}"
  associate_public_ip_address = "${var.associate_public_ip_address}"

  ebs_optimized = "${var.root_volume_ebs_optimized}"

  root_block_device {
    volume_type           = "${var.root_volume_type}"
    volume_size           = "${var.root_volume_size}"
    delete_on_termination = "${var.root_volume_delete_on_termination}"
  }

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL WHAT REQUESTS CAN GO IN AND OUT OF EACH EC2 INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "lc_security_group" {
  name_prefix = "${var.cluster_name}"
  description = "Security group for the ${var.cluster_name} launch configuration"
  vpc_id      = "${var.vpc_id}"

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
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

  security_group_id = "${aws_security_group.lc_security_group.id}"
}

resource "aws_security_group_rule" "allow_ssh_inbound_from_security_group_ids" {
  count                    = "${length(var.allowed_ssh_security_group_ids)}"
  type                     = "ingress"
  from_port                = "${var.ssh_port}"
  to_port                  = "${var.ssh_port}"
  protocol                 = "tcp"
  source_security_group_id = "${element(var.allowed_ssh_security_group_ids, count.index)}"

  security_group_id = "${aws_security_group.lc_security_group.id}"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.lc_security_group.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE ZOOKEEPER-SPECIFIC INBOUND/OUTBOUND RULES COME FROM THE ZOOKEEPER-SECURITY-GROUP-RULES MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "security_group_rules" {
  source = "../zookeeper-security-group-rules"

  security_group_id                  = "${aws_security_group.lc_security_group.id}"
  allowed_inbound_cidr_blocks        = ["${var.allowed_inbound_cidr_blocks}"]
  allowed_inbound_security_group_ids = ["${var.allowed_inbound_security_group_ids}"]

  zookeeper_client_port = "${var.zookeeper_client_port}"
  zookeeper_peer_port   = "${var.zookeeper_peer_port}"
  zookeeper_elect_port  = "${var.zookeeper_elect_port}"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM ROLE TO EACH EC2 INSTANCE
# We can use the IAM role to grant the instance IAM permissions so we can use the AWS CLI without having to figure out
# how to get our secret AWS access keys onto the box.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "${var.cluster_name}"
  path        = "${var.instance_profile_path}"
  role        = "${aws_iam_role.instance_role.name}"

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = "${var.cluster_name}"
  assume_role_policy = "${data.aws_iam_policy_document.instance_role.json}"

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE IAM POLICIES COME FROM THE ZOOKEEPER-IAM-POLICIES MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "iam_policies" {
  source = "../zookeeper-iam-policies"

  iam_role_id             = "${aws_iam_role.instance_role.id}"
  zookeeper_config_bucket = "trustnet-dev-zookeeper-config"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE ZOOKEEPER CONFIGURATION BUCKET COMES FROM THE ZOOKEEPER-CONFIG-BUCKET MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "zookeeper_config" {
  source = "../zookeeper-config-bucket"

  zookeeper_config_bucket = "${var.zookeeper_config_bucket}"
}

# ---------------------------------------------------------------------------------------------------------------------
# Testing Lambda function to update dns on asg event.
# ---------------------------------------------------------------------------------------------------------------------

# Create sns topic
resource "aws_sns_topic" "zookeeper_asg_updates" {
  name = "zookeeper-asg-updates-topic"
}

# Configure ASG to publish event notifications
resource "aws_autoscaling_notification" "zookeeper_asg_notifications" {
  group_names = [
    "${aws_autoscaling_group.autoscaling_group.name}",
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
  ]

  topic_arn = "${aws_sns_topic.zookeeper_asg_updates.arn}"
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name_prefix        = "lambda-zookeeper-"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_role.json}"

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "lambda_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_asg_route53" {
  name = "lambda-asg-route53"
  role = "${aws_iam_role.lambda_role.id}"
  policy = "${data.aws_iam_policy_document.lambda_asg_route53.json}"
}

data "aws_iam_policy_document" "lambda_asg_route53" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:Describe*",
      "cloudfront:ListDistributions",
      "cloudwatch:Describe*",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:Describe*",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRegions",
      "ec2:DescribeVpcs",
      "elasticbeanstalk:DescribeEnvironments",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DescribeLoadBalancers",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "route53:*",
      "route53domains:*",
      "s3:GetBucketLocation",
      "s3:GetBucketWebsite",
      "s3:ListBucket",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTopics",
    ]

    resources = ["*"]
  }
}

# Create Lambda function to process ASG events.
variable "asg_lambda_file" {
  description = "File to use for the ASG Lambda function"
  default     = "./examples/root-example/asg_dns_updater.zip"
}

resource "aws_lambda_function" "zookeeper_asg_dns_lambda" {
  function_name = "asg_dns_updater"

  filename         = "${var.asg_lambda_file}"
  handler          = "asg_dns_updater.handler"
  role             = "${aws_iam_role.lambda_role.arn}"
  source_code_hash = "${base64sha256(file("${var.asg_lambda_file}"))}"

  runtime     = "nodejs8.10"
  memory_size = 128
  timeout     = 10

  vpc_config {
    subnet_ids         = ["${var.subnet_ids}"]
    security_group_ids = ["${aws_security_group.lc_security_group.id}"]
  }
}

resource "aws_lambda_alias" "asg_event" {
    name                 = "asg_event"
    description          = "Autoscaling event"

    function_name        = "${aws_lambda_function.zookeeper_asg_dns_lambda.arn}"
    function_version     = "$LATEST"
}

resource "aws_lambda_permission" "asg_event" {
    function_name        = "${aws_lambda_function.zookeeper_asg_dns_lambda.arn}"

    statement_id         = "AllowExecutionFromSNS"
    action               = "lambda:InvokeFunction"
    principal            = "sns.amazonaws.com"

    source_arn           = "${aws_sns_topic.zookeeper_asg_updates.arn}"
}

resource "aws_sns_topic_subscription" "asg_event" {
    topic_arn            = "${aws_sns_topic.zookeeper_asg_updates.arn}"

    protocol             = "lambda"

    endpoint             = "${aws_lambda_function.zookeeper_asg_dns_lambda.arn}"
}
