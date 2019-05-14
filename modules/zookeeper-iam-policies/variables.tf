# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "iam_role_id" {
  description = "The ID of the IAM Role to which these IAM policies should be attached"
}

variable "zookeeper_config_bucket" {
  description = "The name of the S3 bucket for the Zookeeper configuration. To be read by Exhibitor."
}

