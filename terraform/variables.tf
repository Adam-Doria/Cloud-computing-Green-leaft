
//Global
variable "environment" {
  description = "Environnement de déploiement (dev, preprod, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "preprod", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'preprod' ou 'prod'."
  }
}

//DB
variable "db_password" {
  description = "Mot de passe maître pour RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Nom d'utilisateur maître pour RDS"
  type        = string
  default     = "postgres"
}

variable "db_name" {
  description = "Nom de la base de données à créer"
  type        = string
  default     = "medusa"
}

variable "db_instance_class" {
  description = "Classe d'instance RDS"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Stockage alloué en Go pour RDS"
  type        = number
  default     = 20
}

//Cache
variable "redis_node_type" {
  description = "Type de noeud ElastiCache Redis"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Version du moteur Redis"
  type        = string
  default     = "7.0"
}

// S3 / R2 Cloudflare Configuration
variable "s3_url" {
  description = "Endpoint S3 ou Cloudflare R2"
  type        = string
}

variable "s3_access_key" {
  description = "Access Key ID pour S3/R2"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Secret Access Key pour S3/R2"
  type        = string
  sensitive   = true
}

variable "repo_branch" {
  description = "Branche Git à cloner"
  type        = string
  default     = "main"
}

variable "medusa_publishable_key" {
  description = "La clé publique Medusa (définie par nous)"
  type        = string
  sensitive = true
}
