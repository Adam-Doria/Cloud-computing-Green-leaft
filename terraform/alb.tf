resource "aws_security_group" "alb_sg" {
  name        = "greenleaf-groupe2-alb-sg"
  description = "Security Group pour l'ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS depuis Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_lb" "main" {
  name               = "greenleaf-groupe2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false

  tags = {
    Name        = "greenleaf-groupe2-alb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app" {
  name     = "greenleaf-groupe2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/app" # Demande utilisateur
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200-299"
  }

  tags = {
    Name        = "greenleaf-groupe2-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Attachement des instances au Target Group
resource "aws_lb_target_group_attachment" "medusa_a" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.medusa_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "medusa_b" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.medusa_b.id
  port             = 80
}

output "alb_dns_name" {
  description = "DNS de l'Application Load Balancer"
  value       = aws_lb.main.dns_name
}
