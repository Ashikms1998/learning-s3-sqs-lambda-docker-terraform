# This project:
# image_uri = ECR image URL
# Docker image


# What is ECR?
# ECR = Elastic Container Registry
# It is Docker Hub but for AWS
# It is a place to store your Docker images in AWS
# So Lambda can download and run them

# Without ECR:
#   Your Docker image sits on your laptop
#   Lambda cannot access it ❌

# With ECR:
#   1. Build Docker image
#   2. Push to ECR (in AWS)
#   3. Lambda pulls from ECR
#   4. Lambda runs the container ✅

# ECR is like S3 but for Docker images
# S3 = store files (images, videos, documents)
# ECR = store Docker images (containers)





# 1. ECR Repository (where Docker image is stored)
resource "aws_ecr_repository" "image_resizer" {
  name = "image-resizer"
}

# 2. Lambda Function (using Docker image instead of zip)
resource "aws_lambda_function" "image_resizer" {
  function_name = "image-resizer"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"                              # Docker image not zip
  image_uri     = "${aws_ecr_repository.image_resizer.repository_url}:latest"
  timeout       = 30
  memory_size   = 512                                  # more memory for image processing

  environment {
    variables = {
      ENVIRONMENT   = "dev"
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
}

# 3. SQS Trigger 
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_queue.arn
  function_name    = aws_lambda_function.image_resizer.arn
  batch_size       = 1
  enabled          = true
}






### What's new — explained:

# **`aws_ecr_repository`:**

# ECR Repository = a storage box for Docker images
#                  like a folder that holds your image

# Without this:
#   You build Docker image → nowhere to store it ❌
#   Lambda has no image to pull from ❌

# With this:
#   You build Docker image → push to ECR ✅
#   Lambda pulls from ECR → runs it ✅


# **`package_type = "Image"`:**


# This project:
#   package_type = "Image"
#   Lambda pulls Docker image → runs container


# **`image_uri`:**

# image_uri = "${aws_ecr_repository.image_resizer.repository_url}:latest"

# This is the address of your Docker image in ECR:
#   repository_url = where ECR is
#   :latest        = which version of the image to use

# Like a postal address for your Docker image
# Lambda goes to this address and pulls the image


# **`memory_size = 512`:**

# This project:  512MB  (image resizing needs more power)

# More memory = more CPU automatically in Lambda
# Sharp needs enough RAM to process images ✅