# 1. Le Rôle IAM (L'identité)
resource "aws_iam_role" "app_role" {
  name = "greenleaf-app-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "greenleaf-app-role-${var.environment}"
  }
}

# 2. Attachement de la stratégie SSM (Les permissions)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Le Profil d'Instance (Le conteneur pour EC2)
resource "aws_iam_instance_profile" "app_profile" {
  name = "greenleaf-app-profile-${var.environment}"
  role = aws_iam_role.app_role.name
}