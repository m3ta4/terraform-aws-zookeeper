# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A ZOOKEEPER ENSEMBLE IN AWS
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket  = "trustnet-dev-terraform"
    encrypt = true
    key     = "us-west-2/dev/services/zookeeper/terraform.tfstate"
    profile = "trustnet-dev"
    region  = "us-west-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket  = "trustnet-dev-terraform"
    encrypt = true
    key     = "us-west-2/dev/vpc/terraform.tfstate"
    profile = "trustnet-dev"
    region  = "us-west-2"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOMATICALLY LOOK UP THE LATEST PRE-BUILT AMI
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

data "template_file" "user_data_server" {
  template = "${file("${path.module}/examples/root-example/user-data-server.sh")}"

  vars {
    zookeeper_01   = "zookeeper_01" // compose this like using the same way you do for the resource record.
    zookeeper_02   = "zookeeper_02"
    zookeeper_03   = "zookeeper_03"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ZOOKEEPER SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "zookeeper_ensemble" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::http://git@gogs.devlab.local/Venafi/terraform-aws-zookeeper.git//modules/zookeeper-ensemble?ref=develop"
  source = "modules/zookeeper-ensemble"

  cluster_name  = "trustnet-dev-zookeeper"
  cluster_size  = "3"
  instance_type = "t2.micro"
  ami_id        = "${data.aws_ami.zookeeper.image_id}"
  user_data     = "${data.template_file.user_data_server.rendered}"
  vpc_id        = "${data.terraform_remote_state.vpc.vpc_id}"
  subnet_ids    = "${data.terraform_remote_state.vpc.private_subnets}"

  # To make testing easier, we allow Zookeeper and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "deploy-dev"

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
  ]
}
