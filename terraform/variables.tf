
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

//Cloudflare
variable "cloudflare_api_token" {
  description = "Token API Cloudflare pour gérer R2"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "ID du compte Cloudflare"
  type        = string
}

variable "r2_bucket_name" {
  description = "Nom du bucket R2"
  type        = string
  default     = "greanleaft-groupe2-bucket"
}
