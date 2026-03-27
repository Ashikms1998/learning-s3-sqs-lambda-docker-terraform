#Step 3 — Create S3 Buckets

# This project have :
#                        Two buckets
#                        image-input-bucket   → user uploads here
#                        image-output-bucket  → resized images saved here


# 1. Input bucket (user uploads here)
resource "aws_s3_bucket" "input_bucket" {
  bucket = "image-input-bucket"

  tags = {
    Name        = "image-input-bucket"
    Environment = "dev"
  }
}

# 2. Output bucket (resized images saved here)
resource "aws_s3_bucket" "output_bucket" {
  bucket = "image-output-bucket"

  tags = {
    Name        = "image-output-bucket"
    Environment = "dev"
  }
}

# 3. Notify SQS when image is uploaded to INPUT bucket only
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  queue {
    queue_arn = aws_sqs_queue.image_queue.arn
    events    = ["s3:ObjectCreated:*"]
    filter_suffix = ".jpg"    # only trigger for jpg files
  }
}












### What's — `filter_suffix`:


#  filter_suffix = ".jpg"
#  ONLY jpg uploads trigger Lambda ✅

# Why?
#  We are building an image resizer
#  No point triggering Lambda for .txt or .pdf files
#  Filter keeps it clean and efficient

# can also add more filters later:

#  filter_prefix = "uploads/"  # only files in this folder
#  filter_suffix = ".jpg"      # only jpg files
#  filter_prefix = "uploads/" AND filter_suffix = ".jpg"  # both must match
# filter_suffix = ".png" # would need a separate queue block


### How both buckets are used in the full flow:

# image-input-bucket           # image-output-bucket
#         │                            │
# User uploads image.jpg               │
#         │                            │
# S3 notifies SQS                      │
#         │                            │
# Lambda downloads image.jpg           │
# from INPUT bucket                    │
#         │                            │
# Lambda resizes into 3 versions       │
#         │                            │
# Lambda saves to OUTPUT bucket ───────┘
#  resized/small/image.jpg
#  resized/medium/image.jpg
#  resized/large/image.jpg



### Why S3 notification triggers SQS (not Lambda directly):

# S3 → SQS → Lambda is the standard pattern
# Why not S3 → Lambda directly?

# 1. Reliability
#    - SQS acts as a buffer
#    - If Lambda is down, SQS holds the message
#    - Lambda processes when it comes back online
#    - Direct S3 → Lambda would lose the event if Lambda is down

# 2. Decoupling
#    - S3 doesn't need to know about Lambda
#    - Lambda doesn't need to know about S3
#    - They only know about SQS
#    - Makes system easier to manage and scale

# 3. Batching
#    - SQS can batch multiple messages
#    - Lambda can process them in batches
#    - More efficient than one-by-one

# 4. Error handling
#    - SQS has dead-letter queues (DLQ)
#    - Failed messages go to DLQ for inspection
#    - Can retry or manually process later

# 5. Scalability
#    - SQS handles massive throughput
#    - Lambda can scale independently
#    - Together they handle huge loads

# 6. Security
#    - SQS policies control access
#    - Lambda policies control access
#    - Easier to manage permissions

# 7. Monitoring
#    - CloudWatch metrics for SQS
#    - CloudWatch metrics for Lambda
#    - Easier to see what's happening

# 8. Cost
#    - SQS is very cheap
#    - Lambda only runs when there's work
#    - More cost-effective than constant polling

# 9. Flexibility
#    - Can add more Lambdas later
#    - Can add other consumers (e.g., SNS)
#    - All using the same SQS queue

# 10. Durability
#     - SQS messages are stored durably
#     - Not lost if systems fail
#     - Can be reprocessed if needed

# Summary:
# S3 → SQS → Lambda is the standard, reliable, scalable pattern
# Direct S3 → Lambda is possible but less robust
# SQS adds buffering, error handling, and flexibility


### Output bucket folder structure after Lambda runs:

# image-output-bucket/
#   └── resized/
#         ├── small/
#         │     └── image.jpg    (320x320)
#         ├── medium/
#         │     └── image.jpg    (640x640)
#         └── large/
#               └── image.jpg    (1280x1280)