resource "aws_launch_template" "app" {
  name_prefix   = "greenleaf-lt-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux_2023.id # Défini dans nat_instances.tf
  instance_type = "t3.small"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      delete_on_termination = true
    }
  }

  # Sécurité Réseau
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Identité IAM (SSM)
  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name # Défini dans iam.tf
  }

  # Script de démarrage
  user_data = base64encode(templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    db_url    = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
    redis_url = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"
    s3_url    = var.s3_url
    s3_key    = var.s3_access_key
    s3_secret = var.s3_secret_key
    branch_name = var.repo_branch
    publishable_key = var.medusa_publishable_key
  }))

  # Tags pour les instances EC2 créées par ce template
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "greenleaf-app-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  # Tags pour les disques (EBS) attachés
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "greenleaf-app-disk-${var.environment}"
      Environment = var.environment
    }
  }

  # Tags pour le Launch Template lui-même
  tags = {
    Name        = "greenleaf-launch-template-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}