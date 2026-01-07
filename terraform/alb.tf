# 1. L'Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "greenleaf-groupe2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Placé dans les zones publiques

  tags = { Name = "greenleaf-groupe2-alb" }
}

# 2. Le Target Group (Groupe de destination sur le port 80)
resource "aws_lb_target_group" "medusa_tg" {
  name     = "greenleaf-medusa-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Le Listener (Écoute le port 80 pour rediriger vers le Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.medusa_tg.arn
  }
}

# 4. Liaison des instances existantes au Load Balancer
resource "aws_lb_target_group_attachment" "medusa_a" {
  target_group_arn = aws_lb_target_group.medusa_tg.arn
  target_id        = aws_instance.medusa_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "medusa_b" {
  target_group_arn = aws_lb_target_group.medusa_tg.arn
  target_id        = aws_instance.medusa_b.id
  port             = 80
}