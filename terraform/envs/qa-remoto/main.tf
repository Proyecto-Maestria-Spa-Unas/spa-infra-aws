locals {
  environment = "qa-remoto"

  tags = {
    Project     = var.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repository  = "Proyecto-Maestria-Spa-Unas/spa-infra-aws"
    Purpose     = "remote-qa-testing"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
