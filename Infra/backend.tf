terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "venkat-bankapp-state-bucket"
    key            = "eks-bankapp/terraform.tfstate"
    region         = "ap-south-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}