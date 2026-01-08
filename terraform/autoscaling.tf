# Launch template (Le moule des serveurs)
resource "aws_launch_template" "app" {
  name_prefix   = "greenleaf-groupe2-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # User Data : Installation au démarrage (Docker + Medusa)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user
              # Ici viendra le docker-compose up...
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "greenleaf-groupe2-app-instance" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto scaling group
resource "aws_autoscaling_group" "app" {
  name = "greenleaf-groupe2-asg"

  vpc_zone_identifier = [aws_subnet.private_app_a.id, aws_subnet.private_app_b.id]
  target_group_arns   = [aws_lb_target_group.app.arn]

  # AC : Health Check "ELB" (Indispensable pour la fiabilité applicative)
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # AC : Instance Refresh (Rolling Update), permet de mettre à jour les serveurs sans couper le service
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # 50% des serveurs vivants pendant l'update
    }
  }

  tag {
    key                 = "Name"
    value               = "greenleaf-groupe2-asg-node"
    propagate_at_launch = true
  }
}

# Scaling policy, Target Tracking Policy (Cible : 60% CPU moyen)
resource "aws_autoscaling_policy" "cpu_policy" {
  name                   = "greenleaf-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
