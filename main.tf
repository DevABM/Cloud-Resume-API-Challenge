provider "github" {
  token = var.github_token
  owner = var.github_owner
}

resource "github_repository" "example" {
  name        = var.repo_name
  description = "This repository contains Terraform configurations to deploy an AWS Lambda function and DynamoDB table"
  visibility  = "public" # Use "private" for a private repository

  lifecycle {
    create_before_destroy = true
  }
}

provider "aws" {
  region = var.aws_region
}

# resource "aws_dynamodb_table" "resume_table" {
#   name         = "Resumes"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "ID"

#   attribute {
#     name = "ID"
#     type = "S"
#   }

# }

# locals {
#   resume_items = file("${path.module}/resume.json")
# }
locals {
  resume_items_raw = file("${path.module}/resume.json")
  resume_items     = jsondecode(local.resume_items_raw)
}
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

resource "aws_lambda_function_url" "resume_lambda_url" {
  function_name = aws_lambda_function.resume_lambda.function_name

  authorization_type = "NONE"
}
/*
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "resume_api"
  description   = "API Gateway trigger for Lambda function "
  protocol_type = "HTTP"
  target        = aws_lambda_function.resume_lambda.arn

}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.resume_lambda.arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /resumes"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}
}
*/
# API Gateway REST API
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