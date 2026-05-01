# Latest Ubuntu 22.04 LTS AMI (amd64, hvm, gp2)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "k3s" {
  name        = "${var.project}-${var.environment}-k3s-sg"
  description = "Security group for k3s node"
  vpc_id      = var.vpc_id

  # SSH — locked to your IP only
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # HTTP for app NodePort
  ingress {
    description = "HTTP app"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana NodePort
  ingress {
    description = "Grafana"
    from_port   = 30300
    to_port     = 30300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-k3s-sg" }
}

resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM access so you can connect without opening port 22 to 0.0.0.0/0
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  # Install k3s on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y curl
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
    # Allow ubuntu user to use kubectl without sudo
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    chmod 600 /home/ubuntu/.kube/config
    sed -i 's/127.0.0.1/localhost/g' /home/ubuntu/.kube/config
  EOF

  tags = { Name = "${var.project}-${var.environment}-k3s" }
}
