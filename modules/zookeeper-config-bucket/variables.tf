# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "zookeeper_config_bucket" {
  description = "The name of the S3 bucket for the Zookeeper configuration. To be read by Exhibitor."
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "versioning_enabled" {
  description = "Enable bucket versioning."
  default     = true
}
