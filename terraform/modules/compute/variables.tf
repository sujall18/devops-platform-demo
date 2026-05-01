variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC to place the instance in"
  type        = string
}

variable "public_subnet_id" {
  description = "Subnet for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your IP in CIDR notation for SSH access"
  type        = string
}
