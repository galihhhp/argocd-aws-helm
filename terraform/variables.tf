variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "argocd-aws-helm"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone_1a" {
  description = "Availability zone for subnets"
  type        = string
  default     = "ap-southeast-1a"
}

variable "availability_zone_1b" {
  description = "Availability zone for subnets"
  type        = string
  default     = "ap-southeast-1b"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "fullstack-app-cluster"
}

variable "node_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.small"
}

variable "node_count" {
  description = "Number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_access_entries" {
  description = "List of IAM principal ARNs (users or roles) that need access to the EKS cluster. If empty, uses the current AWS caller identity."
  type        = list(string)
  default     = []
}
