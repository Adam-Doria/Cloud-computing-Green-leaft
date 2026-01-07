# 1. Récupérer dynamiquement l'AMI Amazon Linux 2023 la plus récente
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Security Group pour les NAT (Autorise le trafic interne du VPC)
resource "aws_security_group" "nat_sg" {
  name   = "greenleaf-groupe2-nat-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Instance NAT dans la Zone A
resource "aws_instance" "nat_a" {
  ami           = data.aws_ami.amazon_linux_2023.id # Utilise l'AMI dynamique
  instance_type = "t3.nano"
  subnet_id     = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  source_dest_check      = false # INDISPENSABLE pour router le trafic

  user_data = <<-EOF
              #!/bin/bash
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p
              dnf install -y iptables-services
              iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
              service iptables save
              systemctl enable iptables
              systemctl start iptables
              EOF
  tags = { Name = "greenleaf-groupe2-nat-a" }
}

# 4. Instance NAT dans la Zone B
resource "aws_instance" "nat_b" {
  ami           = data.aws_ami.amazon_linux_2023.id # Utilise la même AMI dynamique
  instance_type = "t3.nano"
  subnet_id     = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  source_dest_check      = false
  
  user_data = aws_instance.nat_a.user_data
  tags = { Name = "greenleaf-groupe2-nat-b" }
}