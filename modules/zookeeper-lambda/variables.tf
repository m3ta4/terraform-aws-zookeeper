# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "asg_group_names" {
  description = "Autoscaling groups to notify on."
}

variable "asg_lambda_file" {
  description = "File to use for the ASG Lambda function"
}

variable "lambda_alias" {
  description = "The alias of the lambda function for the ASG."
}

variable "lambda_function_name" {
  description = "The name of the lambda function for the ASG."
}

variable "security_group_ids" {
  description = "A list of security group IDs associated with the Lambda function."
  type        = "list"
}

variable "subnet_ids" {
  description = "A list of subnet IDs associated with the Lambda function."
  type        = "list"
}

