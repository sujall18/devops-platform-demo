output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance running k3s"
  value       = module.compute.instance_public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.compute.instance_public_ip}"
}
