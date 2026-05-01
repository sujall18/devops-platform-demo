output "instance_id" {
  value = aws_instance.k3s.id
}

output "instance_public_ip" {
  value = aws_instance.k3s.public_ip
}
