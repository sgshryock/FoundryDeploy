# FoundryDeploy AWS EC2 Terraform Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "foundry"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID (leave empty to use latest Ubuntu 22.04)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 50
}

variable "create_vpc" {
  description = "Create a new VPC (false uses default VPC)"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet (only used if create_vpc is true)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_elastic_ip" {
  description = "Create and associate an Elastic IP"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "FoundryVTT"
    ManagedBy = "Terraform"
  }
}
