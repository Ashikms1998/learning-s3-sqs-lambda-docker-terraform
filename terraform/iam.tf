# IAM Role + Policies 

# This project:
#    SQS read permission        ✅
#    CloudWatch logs             ✅ 
#    S3 read (input bucket)      ✅ 
#    S3 write (output bucket)    ✅ 
#    ECR read (pull Docker image) ✅

# 1. Read image FROM input bucket
# 2. Write resized images TO output bucket
# 3. Pull Docker image FROM ECR

# 1. IAM Role

resource "aws_iam_role" "lambda_role" {
  name = "image-resizer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}



# 2. SQS Permission (same as last project)

resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda-sqs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.image_queue.arn
    }]
  })
}



# 3. S3 Permission (NEW this project)

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"        # read image from input bucket
        ]
        Resource = "${aws_s3_bucket.input_bucket.arn}/*"   # any file inside input bucket
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"        # write resized image to output bucket
        ]
        Resource = "${aws_s3_bucket.output_bucket.arn}/*"  # any file inside output bucket
      }
    ]
  })
}



# 4. CloudWatch Permission (same as last project)

resource "aws_iam_role_policy" "lambda_cloudwatch_policy" {
  name = "lambda-cloudwatch-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}


# For ECR:
#   ecr:GetAuthorizationToken is a global action
#   it does not apply to a specific repository
#   it ONLY works with Resource = "*" ← AWS requirement

#   ecr:BatchGetImage and ecr:GetDownloadUrlForLayer
#   technically can be scoped to specific repo
#   but * is acceptable and simpler for now ✅








# 1. S3 read (input bucket)
# Lambda needs to download the image that was uploaded
# Without this → Lambda can't get the image → crash ❌

# 2. S3 write (output bucket)
# Lambda needs to save the resized images
# Without this → Lambda can't save resized images → crash ❌

# 3. ECR read (pull Docker image)
# Lambda needs to load the Docker image from ECR
# Without this → Lambda can't start → crash ❌


# 1. SQS read permission
# Lambda needs to read messages from SQS queue
# Without this → Lambda never knows there's an image to resize ❌

# 2. CloudWatch logs permission
# Lambda needs to write logs
# Without this → you can't see errors or debug → very hard to fix ❌


# Resource = "${aws_s3_bucket.input_bucket.arn}/*"


# Without /* :
#   arn:aws:s3:::image-input-bucket
#   → permission on the BUCKET ITSELF
#   → cannot read files inside it ❌

# With /* :
#   arn:aws:s3:::image-input-bucket/*
#   → permission on EVERYTHING INSIDE the bucket
#   → can read any file inside it ✅

# Think of it like:
#   Without /* → you can see the folder exists
#   With /*    → you can open files inside the folder

### Why separate statements for input and output:

# We need two different permissions:
# 1. Read from input bucket
# 2. Write to output bucket

# They have different ARNs:
# Input:  arn:aws:s3:::image-input-bucket/*
# Output: arn:aws:s3:::image-output-bucket/*

# If we combine them:
# Resource = "${aws_s3_bucket.input_bucket.arn}/*"
#            "${aws_s3_bucket.output_bucket.arn}/*"

# This doesn't work in IAM policies
# Each statement needs ONE resource ARN

# So we use two separate statements:
# Statement 1 → input bucket (read)
# Statement 2 → output bucket (write)

# Both attached to the same IAM role

# Statement 1:
#   Action   = s3:GetObject         → READ only
#   Resource = input_bucket/*       → input bucket only
#   Lambda can READ from input ✅
#   Lambda cannot WRITE to input ❌ (least privilege)

# Statement 2:
#   Action   = s3:PutObject         → WRITE only
#   Resource = output_bucket/*      → output bucket only
#   Lambda can WRITE to output ✅
#   Lambda cannot READ from output ❌ (not needed)


# This is **least privilege** — Lambda gets exactly what it needs, nothing more.


### Full permission picture now:

# Lambda role has:
#   ├── SQS    → ReceiveMessage, DeleteMessage, GetQueueAttributes
#   ├── S3     → GetObject on input bucket
#   │            PutObject on output bucket
#   ├── Logs   → CreateLogGroup, CreateLogStream, PutLogEvents
#   └── ECR    → GetAuthorizationToken, BatchGetImage,
#                GetDownloadUrlForLayer ← NEW ✅


# Whats Version = "2012-10-17" in IAM policy?

# This is NOT a date you pick or change
# This is AWS's policy language version number

# Think of it like a grammar version:
#   "I am writing this policy using 
#    AWS policy grammar version 2012-10-17"

# It's just the version of the IAM policy language.

# AWS uses JSON for IAM policies.
# JSON has a version field.
# "2012-10-17" is the current version.

# It means:
# "This policy is written in the 2012-10-17 version of the IAM policy language"

# Think of it like:
#   Version: "1.0"
#   Language: English

# It doesn't affect what the policy does.
# It just says which version of the language you're using.

# You can ignore it — it's always "2012-10-17" for all modern policies.
# If you write a different date → policy won't work ❌


# Whats inside Action

# Action = "sqs:ReceiveMessage"
#   → allows Lambda to RECEIVE messages from SQS

# Action = "sqs:DeleteMessage"
#   → allows Lambda to DELETE messages after processing

# Action = "sqs:GetQueueAttributes"
#   → allows Lambda to get queue info (like message count)

# Action = "s3:GetObject"
#   → allows Lambda to GET objects from S3 (download images)

# Action = "s3:PutObject"
#   → allows Lambda to PUT objects into S3 (upload resized images)

# Action = "logs:CreateLogGroup"
#   → allows Lambda to create log group in CloudWatch

# Action = "logs:CreateLogStream"
#   → allows Lambda to create log stream in CloudWatch

# Action = "logs:PutLogEvents"
#   → allows Lambda to write log events to CloudWatch

# sts:AssumeRole
#   → allows Lambda to assume the IAM role


# Why do we need sts:AssumeRole?

# This is the permission that allows Lambda to assume the IAM role.
# Without this → Lambda can't even start ❌

# Think of it like:
#   IAM role = your ID card
#   sts:AssumeRole = permission to show your ID card

# Without permission to show your ID card → you can't prove who you are → can't enter the building ❌

# So sts:AssumeRole is the most basic permission of all.



# Why do we need all these actions?

# Think of it like a recipe:

# 1. ReceiveMessage
#   → "I need to get the recipe from the mailbox"

# 2. DeleteMessage
#   → "I finished the recipe, throw it away so I don't make it again"

# 3. GetQueueAttributes
#   → "How many recipes are waiting?"

# 4. GetObject
#   → "Download the ingredients from the pantry"

# 5. PutObject
#   → "Put the finished dish on the table"

# 6. CreateLogGroup
#   → "Create a notebook to write my cooking notes"

# 7. CreateLogStream
#   → "Create a page in my notebook for this recipe"

# 8. PutLogEvents
#   → "Write my cooking notes in the notebook"

# Without any of these → the recipe fails at that step ❌

# Each action is one specific permission Lambda needs to do its job.

# If you remove any → Lambda will crash at that step.

# Example:
# Remove DeleteMessage → Lambda finishes resizing but never deletes the message
# → message stays in queue → Lambda processes it again → crash ❌

# Remove GetObject → Lambda can't download the image → crash ❌

# Remove PutObject → Lambda can't save the resized image → crash ❌


# Think of AWS as a building with many departments:
#   SQS department   → has its own set of actions
#   S3 department    → has its own set of actions
#   Logs department  → has its own set of actions

# Action = "which department + what you want to do there"

# You can find the full list of actions for any AWS service in their documentation. For example S3 has 50+ actions like:

# s3:GetObject        → download file
# s3:PutObject        → upload file
# s3:DeleteObject     → delete file
# s3:ListBucket       → list files in bucket
# s3:CreateBucket     → create a bucket
# ...and many more



# Principal — WHO is making the request

# Principal = the IDENTITY asking for permission

#Think of it like:
#  "WHO is knocking on the door?"

#Principal = { Service = "lambda.amazonaws.com" }
#  → AWS Lambda service is knocking

#Principal = { Service = "s3.amazonaws.com" }
#  → AWS S3 service is knocking

#Principal = { AWS = "arn:aws:iam::123456789:user/john" }
#  → a specific AWS user named john is knocking




# Why Principal is only in ONE place (assume_role_policy):

# There are TWO types of policies in this project:

# 1. IAM Role Policy (attached to the role)
#    → Defines what the role CAN do
#    → No Principal here (role doesn't ask permission — it IS the permission)

# 2. IAM Policy (attached to S3 bucket)
#    → Defines who can access the bucket
#    → Needs Principal to say WHO can access

# Think of it like:
#   IAM Role Policy = your job description (what you can do)
#   IAM Policy = security guard at the door (who can enter)

# The role doesn't need to say "I am Lambda" — it just IS Lambda.
# The S3 bucket needs to say "Only Lambda can access this".




# if i have to explain much more simpler

# TYPE 1 → TRUST POLICY (has Principal)
#   Question it answers:
#   "WHO is allowed to USE this role?"

#   Used in: assume_role_policy only
#   Has Principal because you need to specify WHO

# TYPE 2 → PERMISSION POLICY (no Principal)
#   Question it answers:
#   "WHAT is this role allowed to DO?"

#   Used in: aws_iam_role_policy
#   No Principal because the role itself is already the WHO


# So in our code:

# assume_role_policy → HAS Principal
#   "Lambda service is allowed to assume this role"
#   WHO = Lambda → needs Principal

# lambda_sqs_policy → NO Principal
#   "This role can read SQS messages"
#   WHO is already known → whoever has the role (Lambda)

# lambda_s3_policy → NO Principal
#   "This role can read/write S3"
#   WHO is already known → whoever has the role (Lambda)

# lambda_cloudwatch_policy → NO Principal
#   "This role can write logs"
#   WHO is already known → whoever has the role (Lambda)



# Why do we need both assume_role_policy AND permission policies?

# Think of it like:
#   assume_role_policy = "You are allowed to be a Lambda"
#   permission policies = "Here is your job description"

# Without assume_role_policy:
#   Lambda can't even start ❌
#   It's like someone saying "You can't be a Lambda"

# Without permission policies:
#   Lambda starts but can't do anything ❌
#   It's like someone saying "You're a Lambda, but you can't read SQS, can't read S3, can't write S3, can't write logs"

# You need BOTH:
# 1. Permission to be a Lambda (assume_role_policy)
# 2. Permission to do your job (permission policies)

# Without either → the whole system fails.


# Resource — What is this policy about?

#Resource = the specific AWS resource the policy applies to

#Think of it like:
#  "WHICH door is this policy for?"

#Resource = aws_sqs_queue.image_queue.arn
#  → This policy is for the image_queue

#Resource = aws_s3_bucket.input_bucket.arn
#  → This policy is for the input_bucket

#Resource = aws_lambda_function.image_resizer.arn
#  → This policy is for the image_resizer Lambda function



# Resource = the exact thing being accessed

# Think of it like:
#   Action   = what you want to DO
#   Resource = what you want to do it TO

# Examples

#  Action   = "s3:GetObject"
# Resource = "arn:aws:s3:::image-input-bucket/*"
# Meaning  = "download files FROM image-input-bucket"

# Action   = "sqs:ReceiveMessage"
# Resource = "arn:aws:sqs:us-east-1:000000000000:image-resizer-queue"
# Meaning  = "read messages FROM image-resizer-queue specifically"

# Action   = "logs:PutLogEvents"
# Resource = "arn:aws:logs:*:*:*"
# Meaning  = "write logs to ANY log group"
#            (* = wildcard = anything)



# What is ARN?

# ARN = Amazon Resource Name
#     = the unique address of anything in AWS

# Format:
# arn:aws:SERVICE:REGION:ACCOUNT_ID:RESOURCE

# Examples:
# arn:aws:s3:::image-input-bucket
#   → S3 bucket called image-input-bucket

# arn:aws:sqs:us-east-1:000000000000:image-resizer-queue
#   → SQS queue in us-east-1 called image-resizer-queue

# arn:aws:logs:*:*:*
#   → any CloudWatch log in any region in any account
#     (* = I don't care, match anything)

# Think of ARN like a postal address:

# Real address:
#   John Smith          → who
#   123 Main Street     → where exactly
#   Mumbai, India       → region

# ARN:
#   s3                  → service (who)
#   image-input-bucket  → exact resource (where exactly)
#   us-east-1           → region



# Full picture of everything together:

# assume_role_policy = {
#   WHO?    → Principal = Lambda
#   DO WHAT? → Action = AssumeRole
#   TO WHAT? → no Resource needed (role itself is the target)
#   ALLOWED? → Effect = Allow
# }

# lambda_sqs_policy = {
#   WHO?    → no Principal (already known = Lambda via role)
#   DO WHAT? → Action = ReceiveMessage, DeleteMessage
#   TO WHAT? → Resource = image-resizer-queue ARN
#   ALLOWED? → Effect = Allow
# }

# lambda_s3_policy = {
#   WHO?    → no Principal (already known = Lambda via role)
#   DO WHAT? → Action = GetObject
#   TO WHAT? → Resource = input-bucket/*
#   ALLOWED? → Effect = Allow

#   WHO?    → no Principal
#   DO WHAT? → Action = PutObject
#   TO WHAT? → Resource = output-bucket/*
#   ALLOWED? → Effect = Allow
# }