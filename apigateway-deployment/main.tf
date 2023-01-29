# Variables
variable "myregion" {
    type = string
    default = "ap-south-1"
}

variable "accountId" {
    type = number
    default = 534346356116
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_api_gateway_rest_api" "api"{
    name = "list_instances_by_region"

}

resource "aws_api_gateway_resource" "resource"{
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "list_ec2"
    rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.resource.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_integration" "integration" {
  http_method = aws_api_gateway_method.method.http_method
  resource_id = aws_api_gateway_resource.resource.id
  rest_api_id = aws_api_gateway_rest_api.api.id
  type        = "AWS"
  integration_http_method = "POST"
  uri = aws_lambda_function.list_instance_lambda.invoke_arn
    request_templates = {
    "application/json" = <<EOF
{
   "instance_state" : "$input.params('state')",
   "instance_region" : "$input.params('region')"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "integation_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

#   # Transforms the backend JSON response to XML
#   response_templates = {
#     "application/xml" = <<EOF
# #set($inputRoot = $input.path('$'))
# <?xml version="1.0" encoding="UTF-8"?>
# <message>
#     $inputRoot.body
# </message>
# EOF
#   }
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_instance_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.resource.path}"
}

resource "aws_lambda_function" "list_instance_lambda" {
  filename      = "lambda.zip"
  function_name = "ec2_instance_list"
  role          = aws_iam_role.role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  timeout = 60

  source_code_hash = filebase64sha256("lambda.zip")
}

# IAM
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "inline_policy" {
    statement {
    sid = "1"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      "arn:aws:logs:${var.myregion}:${var.accountId}:*",
    ]
  }
    statement {
    sid = "2"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.myregion}:${var.accountId}:log-group:/aws/lambda/ec2_instance_list:*",
    ]
  }

}

resource "aws_iam_role" "role" {
  name               = "api_gateway_invoke_lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json # (not shown)

  inline_policy {
    name = "lambda_invoke_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["ec2:Describe*"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  inline_policy {
    name   = "policy-8675309"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resource.id,
      aws_api_gateway_method.method.id,
      aws_api_gateway_integration.integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}