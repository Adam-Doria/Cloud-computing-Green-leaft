
//VPC 

output "vpc_id" {
  description = "ID du VPC principal"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs des sous-réseaux publics"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_app_subnet_ids" {
  description = "IDs des sous-réseaux privés applicatifs"
  value       = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
}

output "private_data_subnet_ids" {
  description = "IDs des sous-réseaux privés data"
  value       = [aws_subnet.private_data_a.id, aws_subnet.private_data_b.id]
}

// RDS

output "rds_endpoint" {
  description = "Endpoint de connexion RDS PostgreSQL (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_hostname" {
  description = "Hostname RDS PostgreSQL (sans le port)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Port RDS PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "Nom de la base de données"
  value       = aws_db_instance.postgres.db_name
}

# Connection string complète pour Medusa (sans le mot de passe pour la sécurité)
output "database_url_template" {
  description = "Template de DATABASE_URL pour Medusa (remplacer <PASSWORD>)"
  value       = "postgres://${var.db_username}:<PASSWORD>@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
}

// ElastiCache

output "redis_endpoint" {
  description = "Endpoint de connexion ElastiCache Redis"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Port ElastiCache Redis"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].port
}

# Connection string complète pour Medusa
output "redis_url" {
  description = "REDIS_URL complète pour Medusa"
  value       = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${aws_elasticache_cluster.redis.cache_nodes[0].port}"
}

// Security Groups

output "app_security_group_id" {
  description = "ID du Security Group applicatif"
  value       = aws_security_group.app_sg.id
}

output "data_security_group_id" {
  description = "ID du Security Group data"
  value       = aws_security_group.data_sg.id
}

# --- Ajout Ticket ALB ---
output "alb_dns_name" {
  description = "L'URL DNS publique du Load Balancer (A mettre dans Cloudflare CNAME)"
  value       = aws_lb.main.dns_name
}
