module "base_infrastructure" {
  providers = {
    aws = aws
  }

  source = "../../modules/base_infrastructure"

  # AWS Variables
  region = var.region
}