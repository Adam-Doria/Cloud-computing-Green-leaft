# Le Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "greenleaf-groupe2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # On le place dans les sous-réseaux PUBLICS
  subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name        = "greenleaf-groupe2-alb"
    Environment = var.environment
  }
}

# Le Groupe Cible (Target Group)
resource "aws_lb_target_group" "app" {
  name     = "greenleaf-groupe2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 30
  }
}

# Le Listener - Règle de routage
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
