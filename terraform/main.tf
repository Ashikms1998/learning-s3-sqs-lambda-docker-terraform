terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
    access_key = "test"
    secret_key = "test"

skip_credentials_validation = true
skip_metadata_api_check = true
skip_requesting_account_id = true

endpoints {
    s3 = "http://localhost:4566"
    sqs = "http://localhost:4566"
    lambda = "http://localhost:4566"
    iam = "http://localhost:4566"
    ecr = "http://localhost:4566" # for Docker image storage

    }
}










# This project adds **ECR** (Elastic Container Registry):

# ECR = AWS's Docker image storage
#       (like DockerHub but inside AWS)

# Lambda needs to pull the Docker image from somewhere
# ECR is where we push it → Lambda pulls from there

# Terraform needs to know:
# 1. Where is ECR?
# 2. What's the image name?
# 3. Which version (tag)?
# 4. Which region?

# In this project:
# ECR = localstack
# Image name = my-image
# Tag = latest
# Region = us-east-1


### How ECR fits into our flow:

# You write Dockerfile
#         ↓
# docker build → creates image on your machine
#         ↓
# docker push → sends image to ECR (LocalStack)
#         ↓
# Terraform tells Lambda:
#   "your code is in THIS ECR image"
#         ↓
# Lambda pulls image from ECR → runs it