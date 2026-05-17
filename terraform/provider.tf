terraform {
  required_version = ">= 1.5.0"

  # Uncomment and configure to store state remotely.
  # This keeps the generated SSH private key out of a local plaintext file
  # and adds locking to prevent concurrent applies.
  #
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "aws-devsecops-homelab/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
    local  = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.region
}
