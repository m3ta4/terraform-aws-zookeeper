output "security_group_id" {
  value = "${aws_security_group.zookeeper.id}"
}

output "zookeeper_ips" {
  value = ["${aws_instance.zookeeper.*.private_ip}"]
}

output "zookeeper_fqdn" {
  value = ["${aws_route53_record.zookeeper.*.fqdn}"]
}

output "zookeeper_servers_fqdn" {
  value = ["${aws_route53_record.zookeeper_server.*.fqdn}"]
}
