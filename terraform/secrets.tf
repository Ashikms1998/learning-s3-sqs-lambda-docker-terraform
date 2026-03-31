resource "aws_ssm_parameter" "output_bucket" {
    name = "/image-resizer/output-bucket"
    type = "String"
    value = aws_s3_bucket.output_bucket.bucket
}

resource "aws_ssm_parameter" "input_bucket" {
    name = "/image-resizer/input-bucket"
    type = "String"
    value = aws_s3_bucket.input_bucket.bucket
}

resource "aws_ssm_parameter" "environment" {
    name = "/image-resizer/environment"
    type = "String"
    value = var.environment
}

resource "aws_secretsmanager_secret" "aws_credentials" {
    name = "/image-resizer/aws-credentials"
    recovery_window_in_days = 0    # 0 = delete immediately (good for dev/LocalStack)
}

resource "aws_secretsmanager_secret_version" "aws_credentials" {
    secret_id = aws_secretsmanager_secret.aws_credentials.id
    secret_string = jsonencode({
        accessKeyId = "test"
        secretAccessKey = "test"
    })
}



### What `recovery_window_in_days = 0` means:

# By default Secrets Manager waits 30 days before deleting a secret
# This is a safety net in production

# For LocalStack/dev:
#   30 day wait is annoying
#   terraform destroy → secret not actually deleted
#   terraform apply again → "secret already exists" error ❌

# recovery_window_in_days = 0 → delete immediately ✅
# Only use 0 in dev/LocalStack
# Keep default (30 days) in production 






# What's fixed vs what you change in each project

# resource "aws_ssm_parameter" "output_bucket" {
#   name  = "/image-resizer/output-bucket"
#   type  = "String"
#   value = aws_s3_bucket.output_bucket.bucket
# }


# FIXED (AWS keywords, never change):
#   resource              → Terraform keyword
#   "aws_ssm_parameter"   → AWS resource type
#   type                  → argument name
#   "String"              → SSM type (String/SecureString/StringList)
#   name                  → argument name
#   value                 → argument name

# YOU CHANGE (your choices):
#   "output_bucket"       → your local Terraform name
#                           can be anything you want
#                           e.g. "my_bucket", "bucket_param"

#   "/image-resizer/output-bucket" → the path in SSM
#                           you decide this naming
#                           convention is /app/what-it-stores
#                           e.g. "/myapp/db-url"
#                                "/myapp/region"

#   aws_s3_bucket.output_bucket.bucket → references your S3 bucket
#                           change to whatever value you want to store
#                           e.g. "us-east-1" for a region
#                                "dev" for environment




# resource "aws_secretsmanager_secret" "aws_credentials" {
#   name = "/image-resizer/aws-credentials"
# }


# FIXED:
#   resource                        → Terraform keyword
#   "aws_secretsmanager_secret"     → AWS resource type
#   name                            → argument name

# YOU CHANGE:
#   "aws_credentials"               → your local Terraform name
#   "/image-resizer/aws-credentials" → path in Secrets Manager
#                                    you decide this





# resource "aws_secretsmanager_secret_version" "aws_credentials" {
#   secret_id     = aws_secretsmanager_secret.aws_credentials.id
#   secret_string = jsonencode({
#     accessKeyId     = "test"
#     secretAccessKey = "test"
#   })
# }


# FIXED:
#   resource                              → Terraform keyword
#   "aws_secretsmanager_secret_version"   → AWS resource type
#   secret_id                             → argument name
#   secret_string                         → argument name
#   jsonencode()                          → Terraform function

# YOU CHANGE:
#   "aws_credentials"   → your local Terraform name
#                        must match the secret above

#   aws_secretsmanager_secret.aws_credentials.id
#                       → references the secret above
#                         change "aws_credentials" to
#                         match whatever you named it above

#   accessKeyId         → the KEY inside your secret
#                         you decide what to call it
#                         your code reads it by this name

#   secretAccessKey     → another KEY inside your secret
#                         you decide

#   "test"              → the actual VALUES
#                         in real AWS these would be real credentials




## IAM Actions — These are ALL fixed AWS keywords:

# "ssm:GetParameter"              → fixed AWS action name
# "ssm:GetParameters"             → fixed AWS action name
# "secretsmanager:GetSecretValue" → fixed AWS action name

# These are AWS API call names
# You cannot change them
# They are like function names in AWS's API

# ssm:              → which service (SSM)
# GetParameter      → which action (read one parameter)
# GetParameters     → which action (read multiple parameters)

# secretsmanager:   → which service
# GetSecretValue    → which action (read a secret)


## Simple way to remember what changes vs what doesn't:

# NEVER changes (AWS keywords):
#   resource types    → "aws_ssm_parameter"
#                       "aws_secretsmanager_secret"
#                       "aws_secretsmanager_secret_version"
#   argument names    → name, type, value, secret_id, secret_string
#   IAM actions       → ssm:GetParameter, secretsmanager:GetSecretValue
#   SSM types         → "String", "SecureString", "StringList"

# ALWAYS changes (your choices):
#   local name        → the word after resource type
#                       "output_bucket", "aws_credentials"
#   path/name value   → "/image-resizer/output-bucket"
#                       you pick the path structure
#   secret keys       → accessKeyId, secretAccessKey
#                       you pick what to call them
#   secret values     → "test", "realpassword"
#                       the actual data you store




# Real example for a different project:

# For an email project instead of image resizer:

# SSM
# resource "aws_ssm_parameter" "sender_email" {  # ← you change this
#   name  = "/email-service/sender-email"         # ← you change this
#   type  = "String"                              # ← fixed
#   value = "noreply@mycompany.com"               # ← you change this
# }

# Secrets Manager
# resource "aws_secretsmanager_secret" "sendgrid" {  # ← you change
#   name = "/email-service/sendgrid-api-key"         # ← you change
# }

# resource "aws_secretsmanager_secret_version" "sendgrid" {
#   secret_id     = aws_secretsmanager_secret.sendgrid.id  # ← matches above
#   secret_string = jsonencode({
#     apiKey = "SG.xxxxxxxxxxxxx"    # ← you decide key name + value
#   })
# }


## One more thing — why TWO resources for Secrets Manager but ONE for SSM:

# SSM:
#   aws_ssm_parameter → creates AND stores value in one step
#   one resource ✅

# Secrets Manager:
#   aws_secretsmanager_secret         → creates the SECRET CONTAINER
#                                       (empty vault)
#   aws_secretsmanager_secret_version → puts the ACTUAL VALUE inside
#                                       (fills the vault)
#   two resources ❌ more complex

# Why two for Secrets Manager?
#   Because you can have MULTIPLE VERSIONS of a secret
#   Version 1 → old password
#   Version 2 → new password (after rotation)
#   AWS keeps history of all versions ✅
#   SSM doesn't have versioning → one resource is enough