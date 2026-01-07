# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "greenleaf-groupe2-vpc" }
}

# Internet Gateway (Sortie vers le monde)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "greenleaf-groupe2-igw" }
}

# --- 2 SOUS-RÉSEAUX PUBLICS (Pour les NAT Instances) ---
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true
  tags = { Name = "greenleaf-groupe2-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"
  map_public_ip_on_launch = true
  tags = { Name = "greenleaf-groupe2-public-b" }
}

# --- 2 SOUS-RÉSEAUX PRIVÉS APP (Pour Medusa/Magento) ---
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "eu-west-3a"
  tags = { Name = "greenleaf-groupe2-private-app-a" }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "eu-west-3b"
  tags = { Name = "greenleaf-groupe2-private-app-b" }
}

# --- 2 SOUS-RÉSEAUX PRIVÉS DATA (Pour RDS / Redis) ---
resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "eu-west-3a"
  tags = { Name = "greenleaf-groupe2-private-data-a" }
}

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.40.0/24"
  availability_zone = "eu-west-3b"
  tags = { Name = "greenleaf-groupe2-private-data-b" }
}

# Table Publique (Tout vers l'IGW) -----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Table Privée Zone A (Tout vers NAT Instance A)
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_a.primary_network_interface_id
  }
}

resource "aws_route_table_association" "priv_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_a.id
}

# Table Privée Zone B (Tout vers NAT Instance B)
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_b.primary_network_interface_id
  }
}

resource "aws_route_table_association" "priv_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_b.id
}