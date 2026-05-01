variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used as a prefix on all resource names"
  type        = string
  default     = "devops-platform-demo"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type — t2.micro is free-tier eligible"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (x.x.x.x/32) — SSH is locked to this"
  type        = string
}
