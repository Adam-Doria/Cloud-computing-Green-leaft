# Instance Medusa - Zone A
resource "aws_instance" "medusa_a" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium" # Requis pour Medusa
  subnet_id     = aws_subnet.private_app_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name      = "key_pair_group2_instances_medusa" # Remplace par le nom de ta clé existante

  tags = {
    Name        = "greenleaf-groupe2-medusa-a"
    Environment = var.environment
  }
}

# Instance Medusa - Zone B (Haute Disponibilité)
resource "aws_instance" "medusa_b" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_app_b.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name      = "key_pair_group2_instances_medusa"

  tags = {
    Name        = "greenleaf-groupe2-medusa-b"
    Environment = var.environment
  }
}