terraform {
  backend "s3" {
    bucket         = "greenleaf-tfstate-p2026-paris"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "greenleaf-tf-lock"
    encrypt        = true
  }
}
