variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  default     = "dev"
}

variable "input_bucket" {
  description = "S3 bucket where users upload images"
  default     = "image-input-bucket"
}

variable "output_bucket" {
  description = "S3 bucket where resized images are saved"
  default     = "image-output-bucket"
}

variable "image_resizer_lambda" {
  description = "Name of the Lambda function"
  default     = "image-resizer"
}

variable "lambda_memory" {
  description = "Memory for Lambda in MB"
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  default     = 30
}

variable "sqs_queue_image_resizer" {
  description = "Main SQS queue name"
  default     = "image-resizer-queue"
}

variable "sqs_dlq_image_resizer" {
  description = "Dead letter queue name"
  default     = "image-resizer-dlq"
}