terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = ">= 4.0" }
    tls    = { source = "hashicorp/tls",    version = ">= 4.0" }
    random = { source = "hashicorp/random", version = ">= 3.0" }
    local  = { source = "hashicorp/local",  version = ">= 2.0" }
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
