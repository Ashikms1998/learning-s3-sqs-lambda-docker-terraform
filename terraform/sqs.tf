# Create SQS + DLQ 

# This project:
# image-resizer-dlq
# image-resizer-queue

# 1. Dead Letter Queue (created first)

resource "aws_sqs_queue" "image_dlq" {
  name                      = "image-resizer-dlq"
  message_retention_seconds = 1209600   # 14 days
}


# 2. Main Queue

resource "aws_sqs_queue" "image_queue" {
  name                       = "image-resizer-queue"
  visibility_timeout_seconds = 60       # higher than Lambda timeout (30s)
  message_retention_seconds  = 86400    # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3             # retry 3 times then go to DLQ
  })
}

# 3. Allow S3 to send messages to this queue
resource "aws_sqs_queue_policy" "image_queue_policy" {
  queue_url = aws_sqs_queue.image_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_queue.arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.input_bucket.arn  # only from input bucket
        }
      }
    }]
  })
}




### Quick reminder of why each setting exists:

# image_dlq
#  └── message_retention = 14 days
#        → gives you maximum time to investigate
#          why an image failed to resize

# image_queue
#  └── visibility_timeout = 60s
#        → Lambda has 30s to resize
#          60s gives safe buffer

#  └── maxReceiveCount = 3
#        → if resizing fails 3 times
#          something is seriously wrong
#          send to DLQ for investigation

# image_queue_policy
#  └── Condition → only input bucket
#        → output bucket cannot accidentally
#          trigger the queue ✅



# whats redrive_policy 

# "After X failures → move message to DLQ"

# That's it. Nothing else.

# maxReceiveCount = 3 means:
#   Attempt 1 → Lambda fails
#   Attempt 2 → Lambda fails
#   Attempt 3 → Lambda fails
#   → message moves to DLQ automatically

# So DLQ is not just about retrying — it's your safety net + investigation tool + alert system.



# whats aws_sqs_queue_policy

# It's a security rule that says:
# "Only THIS S3 bucket can send messages to this queue"

# Without this policy:

#   User uploads image to S3
#         ↓
#   S3 tries to send message to SQS
#         ↓
#   SQS says "who are you? you're not allowed here"
#         ↓
#   ACCESS DENIED ❌
#   No message in queue
#   Lambda never gets triggered

# With it:
# Only s3.amazonaws.com with source ARN of input_bucket
# → safe and controlled ✅



### How this connects to S3:

# s3.tf:
#   input_bucket → on jpg upload → notifies → image_queue.arn

# sqs.tf:
#   image_queue → allows → input_bucket to send messages
#   image_queue → on failure → sends to → image_dlq


# Both files reference each other — Terraform handles the order automatically.






# Full permission picture:

# S3 uploads file
#     ↓
# needs permission to send to SQS
#     ↓ (aws_sqs_queue_policy)
# SQS receives message
#     ↓
# needs permission to trigger Lambda
#     ↓ (aws_lambda_event_source_mapping in lambda.tf)
# Lambda runs
#     ↓
# needs permission to read SQS + read S3 + write S3 + write logs
#     ↓ (aws_iam_role_policy in iam.tf)
# Done ✅