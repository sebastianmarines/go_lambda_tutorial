# main.tf
resource "aws_lambda_function" "go_function" {
  filename      = "lambda-handler.zip"
  function_name = "go-lambda-test"
  handler       = "bootstrap"
  role          = aws_iam_role.iam_for_lambda.arn

  source_code_hash = filebase64sha256("lambda-handler.zip")

  runtime = "go1.x"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# API Gateway

resource "aws_api_gateway_rest_api" "go_api" {
  name        = "go_api"
  description = "This is my API for demonstration purposes"
}

resource "aws_api_gateway_resource" "go_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.go_api.id
  parent_id   = aws_api_gateway_rest_api.go_api.root_resource_id
  path_part   = "test"
}

resource "aws_api_gateway_method" "go_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.go_api.id
  resource_id   = aws_api_gateway_resource.go_api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "go_api_integration" {
  rest_api_id = aws_api_gateway_rest_api.go_api.id
  resource_id = aws_api_gateway_resource.go_api_resource.id
  http_method = aws_api_gateway_method.go_api_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.go_function.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.go_api.id
  resource_id   = aws_api_gateway_rest_api.go_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_root_integration" {
  rest_api_id = aws_api_gateway_rest_api.go_api.id
  resource_id = aws_api_gateway_rest_api.go_api.root_resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.go_function.invoke_arn
}

resource "aws_api_gateway_deployment" "go_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.go_api_integration,
    aws_api_gateway_integration.proxy_root_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.go_api.id
  stage_name  = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.go_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.go_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = aws_api_gateway_deployment.go_api_deployment.invoke_url
}
