Docker = a way to package your code + everything it needs
         into a single box that runs the same everywhere

That box is called a CONTAINER
The recipe to build that box is called a DOCKERFILE
The built box (ready to run) is called an IMAGE

Imagine you make a perfect cup of coffee at home
You want your friend to make the exact same coffee

Without Docker:
  You tell them: "use these beans, this machine,
  this water temperature, this cup size"
  They might get it wrong at any step ❌

With Docker:
  You give them a sealed machine that already has
  everything inside — beans, water, settings
  They just press one button → same coffee every time ✅


Dockerfile  = the RECIPE
              (step by step instructions to build the image)

Image       = the BUILT RESULT of the recipe
              (ready to use, like a snapshot)

Container   = a RUNNING instance of the image
              (the actual thing doing work)


  Dockerfile → docker build → Image → docker run → Container
  recipe         cook         dish        serve      eating


This project uses Sharp library for image resizing

Sharp is special:
  It is NOT pure JavaScript
  It contains C++ code compiled into binary files
  These binaries are OS specific

This is the problem:
  You run npm install on Windows
  Sharp downloads Windows binaries
  Lambda runs on Amazon Linux
  Windows binary on Linux Lambda → CRASH ❌


                Windows               Amazon Linux
                  ↓                       ↓
npm install → sharp.win.node    ≠    sharp.linux.node
              (wrong binary)         (correct binary)  



Dockerfile says:
  "Start FROM Amazon Linux"
  "Run npm install HERE"
  Sharp downloads Linux binaries ✅
  Lambda gets Linux binaries ✅
  No crash ✅

  With Docker (this project):
  your machine → Dockerfile → build image → push to registry
                                                    ↓
                                          LocalStack Lambda
                                          pulls image and runs it


# USECASES OF DLQ

Use 1 → DEBUGGING (most common)
  Message sits in DLQ
  You go and read it
  You see exactly which image failed and why
  You fix the bug
  You manually resend it back to main queue

Use 2 → ALERTING
  You set up a CloudWatch alarm:
  "If DLQ has more than 0 messages → send me an email"
  So you get notified immediately when something fails
  (we'll do this in a future project)

Use 3 → AUDITING
  14 day retention = 14 days of failure history
  You can look back and see:
  "On Monday 50 images failed between 2pm-3pm"
  Helps you find patterns in failures

Use 4 → PREVENTING DATA LOSS
  Without DLQ:
    Message fails 3 times → SQS deletes it forever ❌
    That image request is gone, user never gets resized image

  With DLQ:
    Message fails 3 times → moves to DLQ ✅
    Still exists, can be reprocessed after you fix the bug





The current setup is we should run BY USING ECR

  Docker image → push to ECR → Lambda runs image

Below is the commands to run the current setup

Step 1 — Create ECR Repository

For LocalStack 

awslocal ecr create-repository --repository-name image-resizer

For AWS

aws ecr create-repository --repository-name image-resizer --region us-east-1

Step 2 — Build Docker Image

# Go into lambda folder (where Dockerfile is)
cd lambda

# Build the image
docker build -t image-resizer .

Step 3 — Authenticate Docker with ECR

LocalStack  (no authentication needed):

Real AWS:

# Get ECR login token and authenticate Docker
aws ecr get-login-password --region us-east-1 | docker login \
  --username AWS \
  --password-stdin xxxxxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com


Step 4 — Tag Docker Image for ECR

LocalStack 

docker tag image-resizer:latest localhost:4566/image-resizer:latest

Real AWS:

# Replace xxxxxxxxxxxx with your actual AWS account ID
docker tag image-resizer:latest xxxxxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com/image-resizer:latest


Step 5 — Push Image to ECR

LocalStack

docker push localhost:4566/image-resizer:latest

Real AWS:

docker push xxxxxxxxxxxx.dkr.ecr.us-east-1.amazonaws.com/image-resizer:latest

Step 6 — Verify Image in ECR

LocalStack 

awslocal ecr describe-images --repository-name image-resizer

Real AWS:

aws ecr describe-images --repository-name image-resizer --region us-east-1

Step 7 — Terraform Deploy

cd terraform

# If ECR repo already exists (created manually above)
# import it into Terraform state first:
terraform import aws_ecr_repository.image_resizer image-resizer

# Then deploy everything
terraform init
terraform plan
terraform apply -auto-approve

Step 8 — Test Upload

LocalStack 

awslocal s3 cp ./test-image.jpg s3://image-input-bucket/

AWS

aws s3 cp ./test-image.jpg s3://image-input-bucket/

Step 9 — Check Lambda Logs

LocalStack 

awslocal logs tail /aws/lambda/image-resizer

AWS

aws logs tail /aws/lambda/image-resizer --follow


Step 10 — Verify Resized Images in Output Bucket

LocalStack 

awslocal s3 ls s3://image-output-bucket/resized/ --recursive

AWS

aws s3 ls s3://image-output-bucket/resized/ --recursive


But we do not have ECR in localstack

So we will run BY USING LOCAL DOCKER IMAGE

  Docker → build zip WITH Linux binaries → deploy as zip
  Lambda runs zip (free LocalStack supports this ✅)

  So for that purpose we will do the below changes in the next commit


Before:                        After:
Dockerfile → image → ECR       Dockerfile → builds zip → lambda.zip
lambda.tf uses image_uri       lambda.tf uses filename
needs ECR                      no ECR needed ✅



STEPS FOR WITHOUT ECR ONE 

Build zip using Docker:


# Go to lambda folder
cd E:\s3-sqs-lambda-docker-terraform\lambda

# Build Docker image
docker build -t image-resizer-builder .

# Create a container without running it
docker create --name temp-container image-resizer-builder

# Copy node_modules from container to lambda folder
docker cp temp-container:/var/task/node_modules E:\s3-sqs-lambda-docker-terraform\lambda\node_modules

# Copy index.js too
docker cp temp-container:/var/task/index.js E:\s3-sqs-lambda-docker-terraform\lambda\index.js

# Remove the temp container
docker rm temp-container


Zip everything on Windows:

cd E:\s3-sqs-lambda-docker-terraform\lambda

# Delete old zip if exists
Remove-Item ..\terraform\lambda.zip -ErrorAction SilentlyContinue

# Zip index.js + node_modules together
Compress-Archive -Path .\index.js, .\node_modules -DestinationPath ..\terraform\lambda.zip

Verify zip:

[System.IO.Compression.ZipFile]::OpenRead("E:\s3-sqs-lambda-docker-terraform\terraform\lambda.zip").Entries | Select-Object FullName | Select-Object -First 10


Extract lambda.zip from container:

# Create container without running it
docker create --name temp-container image-resizer-builder

# Copy zip from container to terraform folder
docker cp temp-container:/lambda.zip E:\s3-sqs-lambda-docker-terraform\terraform\lambda.zip

# Remove temp container
docker rm temp-container


Verify zip exists and has correct contents:

# Check zip exists
ls E:\s3-sqs-lambda-docker-terraform\terraform\lambda.zip


# Load the assembly first
Add-Type -AssemblyName System.IO.Compression.FileSystem


# Check first 10 entries inside zip
[System.IO.Compression.ZipFile]::OpenRead("E:\s3-sqs-lambda-docker-terraform\terraform\lambda.zip").Entries | Select-Object FullName | Select-Object -First 10

```

Should show:
```
index.js
node_modules/sharp/...
node_modules/@aws-sdk/...


 Terraform apply:

cd E:\s3-sqs-lambda-docker-terraform\terraform
terraform init
terraform plan
terraform apply -auto-approve


Test upload:

awslocal s3 cp E:\path\to\any-image.jpg s3://image-input-bucket/



What this does:
```
docker build     → builds image with Linux Sharp binaries
docker run       → starts container
cp /lambda.zip   → copies zip from container
/output          → into your terraform folder





























  