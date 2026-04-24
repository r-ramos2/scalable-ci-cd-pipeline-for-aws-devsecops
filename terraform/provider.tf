terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    tls    = { source = "hashicorp/tls" }
    random = { source = "hashicorp/random" }
    local  = { source = "hashicorp/local" }
  }
}

# To enable remote state for collaboration and better safety,
# configure an S3 backend with DynamoDB state locking, for example:
# 
# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state-bucket"
#     key            = "aws-devsecops-homelab/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }

provider "aws" {
  region = var.region
}
