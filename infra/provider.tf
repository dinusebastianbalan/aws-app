terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.6" # which means any version equal & above
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    bucket = "terraform-bday-app"
    key    = "infra-state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}
