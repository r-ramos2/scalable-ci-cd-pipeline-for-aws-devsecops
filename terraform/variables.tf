# Global settings
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "key_name_prefix" {
  description = "Prefix for the auto-generated SSH keypair"
  type        = string
  default     = "devsec-deployer"
}

# Networking
variable "vpc_cidr_block" {
  description = "CIDR block for the primary VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ for the public subnet"
  type        = string
  default     = "us-east-1a"
}

# AMI Lookup
variable "linux2_ami_owner" {
  description = "Owner ID for Amazon Linux 2 AMI"
  type        = string
  default     = "amazon"
}

variable "linux2_ami_name_filter" {
  description = "Filter for Amazon Linux 2 AMI"
  type        = string
  default     = "amzn2-ami-hvm-*-gp2"
}

# Allowed CIDR for access (replace with your public IP /32)
variable "allowed_cidr" {
  description = "CIDR block permitted to reach instances (e.g. 203.0.113.25/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "allowed_cidr must be a valid IPv4 CIDR block, e.g. 203.0.113.25/32"
  }
}

# Ports
variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "http_port" {
  description = "HTTP port for React App"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS port for secure access"
  type        = number
  default     = 443
}

variable "jenkins_port" {
  description = "Jenkins Web UI port"
  type        = number
  default     = 8080
}

variable "sonarqube_port" {
  description = "SonarQube UI port"
  type        = number
  default     = 9000
}

variable "react_port" {
  description = "React App port"
  type        = number
  default     = 3000
}

# EC2 Sizing
variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.large"
}

# Volume Sizes (GB)
variable "root_volume_size" {
  description = "Root EBS volume size for Jenkins"
  type        = number
  default     = 30
}
