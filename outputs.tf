output "lambda_function_url" {
  value = aws_lambda_function_url.resume_lambda_url.function_url
}


output "api_url" {
  description = "The URL of the API Gateway endpoint"
  value       = "https://${aws_api_gateway_rest_api.example.id}.execute-api.${var.aws_region}.amazonaws.com/prod/ResumeFunction"
}

