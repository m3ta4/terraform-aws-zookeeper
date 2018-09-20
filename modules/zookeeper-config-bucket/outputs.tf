output "s3_bucket_arn" {
  value = "${aws_s3_bucket.zookeeper_config.arn}"
}
