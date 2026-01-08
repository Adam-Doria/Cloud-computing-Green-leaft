# Instance Medusa - Zone A
resource "aws_instance" "medusa_a" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Surcharge réseau spécifique à cette instance
  subnet_id = aws_subnet.private_app_a.id

  tags = {
    Name        = "greenleaf-groupe2-medusa-a"
    Environment = var.environment
  }
}

# Instance Medusa - Zone B
resource "aws_instance" "medusa_b" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  subnet_id = aws_subnet.private_app_b.id

  tags = {
    Name        = "greenleaf-groupe2-medusa-b"
    Environment = var.environment
  }
}