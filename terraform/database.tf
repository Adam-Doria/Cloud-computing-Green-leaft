
# Subnet Group pour RDS (utilise les subnets privés Data)

resource "aws_db_subnet_group" "main" {
  name        = "greenleaf-groupe2-db-subnet-group"
  description = "Subnet group pour RDS PostgreSQL"
  subnet_ids  = [
    aws_subnet.private_data_a.id,
    aws_subnet.private_data_b.id
  ]

  tags = {
    Name        = "greenleaf-groupe2-db-subnet-group"
    Environment = var.environment
  }
}

# Subnet Group pour ElastiCache
resource "aws_elasticache_subnet_group" "main" {
  name        = "greenleaf-groupe2-cache-subnet-group"
  description = "Subnet group pour ElastiCache Redis"
  subnet_ids  = [
    aws_subnet.private_data_a.id,
    aws_subnet.private_data_b.id
  ]

  tags = {
    Name        = "greenleaf-groupe2-cache-subnet-group"
    Environment = var.environment
  }
}

# RDS PostgreSQL

resource "aws_db_instance" "postgres" {
  identifier = "greenleaf-groupe2-postgres-${var.environment}"

  # Configuration Engine
  engine         = "postgres"
  engine_version = "15"

  # Configuration Instance
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Configuration Base de Données
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Haute Disponibilité (Multi-AZ uniquement en prod)
  multi_az = var.environment == "prod" ? true : false

  # Réseau
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.data_sg.id]
  publicly_accessible    = false # JAMAIS d'accès public

  # Backup & Maintenance
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protection (évite suppression accidentelle en prod)
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment != "prod" ? true : false
  final_snapshot_identifier = var.environment == "prod" ? "greenleaf-groupe2-postgres-final-${formatdate("YYYYMMDD", timestamp())}" : null

  # Performance Insights (optionnel mais utile)
  performance_insights_enabled = var.environment == "prod" ? true : false

  tags = {
    Name        = "greenleaf-groupe2-postgres-${var.environment}"
    Environment = var.environment
    Ticket      = "Ticket-3"
  }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# ElastiCache Redis

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "greenleaf-groupe2-redis-${var.environment}"
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = 1 # Single Node (suffisant pour sessions/events)
  port                 = 6379

  # Réseau
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.data_sg.id]

  # Configuration
  parameter_group_name = "default.redis7"

  # Maintenance
  maintenance_window = "sun:05:00-sun:06:00"

  # Snapshot (uniquement en prod)
  snapshot_retention_limit = var.environment == "prod" ? 3 : 0
  snapshot_window          = var.environment == "prod" ? "04:00-05:00" : null

  tags = {
    Name        = "greenleaf-groupe2-redis-${var.environment}"
    Environment = var.environment
    Ticket      = "Ticket-3"
  }
}
