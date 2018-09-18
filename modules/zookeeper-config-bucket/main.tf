resource "aws_s3_bucket" "zookeeper_config" {
  bucket = "${var.zookeeper_config_bucket}"

  versioning {
    enabled = "${var.versioning_enabled}"
  }

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.zookeeper_config_bucket}/*",
        "arn:aws:s3:::${var.zookeeper_config_bucket}"
      ]
    }
  ]
}
POLICY
}
