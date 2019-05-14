# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE ZOOKEEPER NODES TO READ EXHIBITOR CONFIG ON S#
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "auto-discover-cluster"
  role   = "${var.iam_role_id}"
  policy = "${data.aws_iam_policy_document.auto_discover_cluster.json}"
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
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
    ]

    resources = [
      "arn:aws:s3:::${var.zookeeper_config_bucket}/*",
      "arn:aws:s3:::${var.zookeeper_config_bucket}"
    ]
  }
}
