output "num_servers" {
  value = "${module.zookeeper_ensemble.cluster_size}"
}

output "asg_name_servers" {
  value = "${module.zookeeper_ensemble.asg_name}"
}

output "launch_config_name_servers" {
  value = "${module.zookeeper_ensemble.launch_config_name}"
}

output "iam_role_arn_servers" {
  value = "${module.zookeeper_ensemble.iam_role_arn}"
}

output "iam_role_id_servers" {
  value = "${module.zookeeper_ensemble.iam_role_id}"
}

output "security_group_id_servers" {
  value = "${module.zookeeper_ensemble.security_group_id}"
}

output "aws_region" {
  value = "${data.aws_region.current.name}"
}

output "zookeeper_ensemble_cluster_tag_key" {
  value = "${module.zookeeper_ensemble.cluster_tag_key}"
}

output "zookeeper_ensemble_cluster_tag_value" {
  value = "${module.zookeeper_ensemble.cluster_tag_value}"
}

