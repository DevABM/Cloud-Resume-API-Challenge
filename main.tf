# Add the required providers and modules
provider "aws" {
  region = var.aws_region
}
# Add the required json file for the table
locals {
  resume_items_raw = file("${path.module}/resume.json")
  resume_items     = jsondecode(local.resume_items_raw)
}
# Add the required DynamoDB table
resource "aws_dynamodb_table" "resumes" {
  name         = "resumes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Add other required attributes and configurations
}

resource "aws_dynamodb_table_item" "resume_items" {
  for_each   = { for idx, item in local.resume_items : idx => item }
  table_name = aws_dynamodb_table.resumes.name
  hash_key   = "id"
  item       = jsonencode(each.value)
}

# Add the required Lambda Execution Role

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Sid    = "",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ],
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  ]
}

# Add the required Lambda Function

resource "aws_lambda_function" "resume_lambda" {
  filename         = "lambda.zip"
  function_name    = "ResumeFunction"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.resumes.name
    }
  }
}
# Add the required Lambda URL

resource "aws_lambda_function_url" "resume_lambda_url" {
  function_name = aws_lambda_function.resume_lambda.function_name

  authorization_type = "NONE"
}

# Add the required API Gateway REST API
resource "aws_api_gateway_rest_api" "example" {
  name        = "example-api"
  description = "Example API"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part    = "example"
}

# API Gateway Method
resource "aws_api_gateway_method" "example" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.example.id
  http_method   = "GET"
  authorization = "NONE"

}

# API Gateway Integration
resource "aws_api_gateway_integration" "example" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.example.id
  http_method             = aws_api_gateway_method.example.http_method
  integration_http_method = "GET"
  type                    = "HTTP"
  uri                     = aws_lambda_function_url.resume_lambda_url.function_url
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name   = "prod"

  depends_on = [
    aws_api_gateway_integration.example
  ]
}