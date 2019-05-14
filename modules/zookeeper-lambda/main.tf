# ---------------------------------------------------------------------------------------------------------------------
# Testing Lambda function to update dns on asg event.
# ---------------------------------------------------------------------------------------------------------------------

# Create sns topic
resource "aws_sns_topic" "zookeeper_asg_updates" {
  name_prefix = "asg_dns_updater-"
}

# Configure ASG to publish event notifications
resource "aws_autoscaling_notification" "zookeeper_asg_notifications" {
  group_names = [
    "${var.asg_group_names}",
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
  name_prefix = "lambda-asg-route53-"
  role        = "${aws_iam_role.lambda_role.id}"
  policy      = "${data.aws_iam_policy_document.lambda_asg_route53.json}"
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

resource "aws_lambda_function" "zookeeper_asg_dns_lambda" {
  function_name = "${var.lambda_function_name}"

  filename         = "${var.asg_lambda_file}"
  handler          = "asg_dns_updater.handler"
  role             = "${aws_iam_role.lambda_role.arn}"
  source_code_hash = "${base64sha256(file("${var.asg_lambda_file}"))}"

  runtime     = "nodejs8.10"
  memory_size = 128
  timeout     = 10

  vpc_config {
    subnet_ids         = ["${var.subnet_ids}"]
    security_group_ids = ["${var.security_group_ids}"]
  }
}

resource "aws_lambda_alias" "asg_event" {
    name                 = "${var.lambda_alias}"
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
