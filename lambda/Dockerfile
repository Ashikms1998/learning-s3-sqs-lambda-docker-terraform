# Dockerfile = a recipe with steps
#              Docker reads it top to bottom
#              each step builds on the previous one
#              result = a Docker image ready to run

# Step 1: Start with a fresh Amazon Linux machine
# Step 2: Copy package.json into it
# Step 3: Run npm install (installs sharp with Linux binaries)
# Step 4: Copy your index.js into it
# Step 5: Tell it what to run when Lambda starts

# Step 1: Start FROM AWS's official Lambda Node.js image
# This is Amazon Linux with Node.js 20 already installed
# Same OS that real AWS Lambda runs on ✅
FROM public.ecr.aws/lambda/nodejs:20

# Step 2: Copy package.json first (before index.js)
# Why first? Docker caches each step
# If index.js changes but package.json doesn't →
# Docker skips npm install → faster rebuilds ✅
COPY package.json .

# Step 3: Install dependencies INSIDE the container
# Sharp now installs Linux binaries (not Windows) ✅
RUN npm install

# Step 4: Copy Lambda function code
COPY index.js .

# Zip everything into lambda.zip
# This is what Terraform will upload to Lambda


RUN dnf install -y zip && \
    zip -r /lambda.zip index.js node_modules/


### Why the order of steps matters (Docker caching):

# Docker builds each step as a LAYER
# Each layer is cached separately

# Scenario: you change index.js but NOT package.json

# Wrong order (package.json after index.js):
#   Step 1: FROM image         → cached ✅
#   Step 2: COPY index.js      → CHANGED → rebuild from here
#   Step 3: COPY package.json  → rebuilt (unnecessary)
#   Step 4: RUN npm install    → rebuilt (unnecessary ❌ slow!)

# Correct order (package.json before index.js):
#   Step 1: FROM image         → cached ✅
#   Step 2: COPY package.json  → cached ✅ (not changed)
#   Step 3: RUN npm install    → cached ✅ (not changed)
#   Step 4: COPY index.js      → CHANGED → rebuild only this
  
# Much faster rebuild ✅

### What `public.ecr.aws/lambda/nodejs:20` gives you:

# This base image already has:
#   ✅ Amazon Linux OS (same as real Lambda)
#   ✅ Node.js 20 installed
#   ✅ Lambda runtime (handles the SQS trigger)
#   ✅ Everything Lambda needs to run

# You just add:
#   → your code (index.js)
#   → your dependencies (sharp, aws-sdk)


### Visual of what Docker builds:

# public.ecr.aws/lambda/nodejs:20   ← base layer
#         +
# package.json copied in            ← layer 2
#         +
# npm install ran                   ← layer 3
# (sharp Linux binaries here ✅)
#         +
# index.js copied in                ← layer 4
#         +
# CMD ["index.handler"]             ← entry point

# = Your final Docker image ✅


### Your folder so far:

# s3-sqs-lambda-docker-terraform/
# ├── terraform/
# │   ├── main.tf      ✅
# │   ├── s3.tf        ✅
# │   ├── sqs.tf       ✅
# │   └── iam.tf       ✅
# └── lambda/
#     ├── index.js     ✅
#     ├── package.json ✅
#     └── Dockerfile   ✅

### What happens next (preview of Step 8):

# Step 8 → lambda.tf tells Terraform:
#   "Lambda's code is not a zip anymore"
#   "It is a Docker image stored in ECR"
#   "Here is the ECR image URL to use"

# So before terraform apply:
#   1. Build Docker image
#   2. Push to LocalStack ECR
#   3. Then terraform apply

# We will do all of this step by step ✅


# What is AWS SDK?SDK = Software Development Kit

# AWS SDK = a collection of tools that lets your 
#           CODE talk to AWS services

# Without SDK:
#   Your code has no way to talk to S3, SQS, Lambda etc.
#   You would have to write raw HTTP requests manually ❌

# With SDK:
#   AWS gives you ready made functions:
#   s3.getObject()  → downloads a file from S3
#   s3.putObject()  → uploads a file to S3
#   sqs.sendMessage() → sends a message to SQS
#   Much easier ✅