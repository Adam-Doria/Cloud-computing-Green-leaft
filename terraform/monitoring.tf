# SNS
resource "aws_sns_topic" "alerts" {
  name = "greenleaf-groupe2-alerts-${var.environment}"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alerte finops (AWS budgets)
resource "aws_budgets_budget" "monthly_cost" {
  name              = "budget-greenleaf-groupe2-${var.environment}"
  budget_type       = "COST"
  limit_amount      = "500"
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  # Alerte 1 : Dépassement RÉEL de 80% (400$)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }

  # Alerte 2 : Prévision (FORECAST) à 100% (500$)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }
}

# Alertes techniques (CloudWatch)

# Alerte 1 : Disponibilité (ALB Unhealthy Hosts), vérifie si des instances échouent derrière le Load Balancer
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "greenleaf-groupe2-alb-unhealthy-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "CRITIQUE: Au moins une instance est HS derrière le Load Balancer."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# Alerte 2 : Performance (ASG CPU High), vérifie si le cluster sature
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "greenleaf-groupe2-asg-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "WARNING: Charge CPU élevée (>85%) sur le cluster Autoscaling."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# Alerte 3 : Base de Données (RDS Free Storage), vérifie l'espace disque restant sur PostgreSQL
resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "greenleaf-groupe2-rds-storage-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"

  # Seuil : 2 Go (en octets)
  threshold = "2000000000"

  alarm_description = "URGENT: Espace disque RDS critique (< 2Go)."
  actions_enabled   = true
  alarm_actions     = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }
}
