# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "security_group_id" {
  description = "The ID of the security group to which we should add the zookeeper security group rules"
}

variable "allowed_inbound_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow connections to zookeeper"
  type        = "list"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "allowed_inbound_security_group_ids" {
  description = "A list of security group IDs that will be allowed to connect to zookeeper"
  type        = "list"
  default     = []
}

variable "zookeeper_client_port" {
  description = "The port used by servers to handle incoming requests from clients."
  default     = 2181
}

variable "zookeeper_peer_port" {
  description = "The port used by peers for intercluster communication."
  default     = 2888
}

variable "zookeeper_elect_port" {
  description = "The port used to handle leader election."
  default     = 3888
}

variable "exhibitor_ui_port" {
  description = "The port used to access the Exhibitor UI Control Pannel."
  default     = 8080
}

