resource "aws_s3_bucket" "zookeeper_config" {
  acl    = "private"
  bucket = "${var.zookeeper_config_bucket}"

  versioning {
    enabled = "${var.versioning_enabled}"
  }

}
