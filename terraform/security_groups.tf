resource "aws_security_group" "app_sg" {
  name        = "greenleaf-groupe2-app-sg"
  description = "Security Group pour les instances applicatives Medusa"
  vpc_id      = aws_vpc.main.id

  # HTTP depuis l'ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH pour debug (peut être restreint ou supprimé en prod)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "greenleaf-groupe2-app-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "greenleaf-groupe2-alb-sg"
  description = "Autorise le trafic HTTP entrant depuis Internet"
  vpc_id      = aws_vpc.main.id

  # Entrée : Tout Internet (Port 80)
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie : Tout autorisé
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "greenleaf-groupe2-alb-sg"
    Environment = var.environment
  }
}

# Security Group pour la couche Data (RDS & Redis)
resource "aws_security_group" "data_sg" {
  name        = "greenleaf-groupe2-data-sg"
  description = "Security Group pour RDS PostgreSQL et ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL depuis les instances applicatives
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
    description     = "PostgreSQL depuis les instances applicatives"
  }

  # Redis depuis les instances applicatives
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
    description     = "Redis depuis les instances applicatives"
  }

  # Pas d'accès internet direct pour la couche Data
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"] # Uniquement trafic interne VPC
  }

  tags = {
    Name        = "greenleaf-groupe2-data-sg"
    Environment = var.environment
  }
}
