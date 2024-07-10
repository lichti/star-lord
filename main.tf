provider "aws" {
  region = var.region
}

resource "aws_iam_role" "lambda_role" {
  name = "star-lord-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
      },
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "star-lord-lambda-policy"
  description = "Policy for Lambda execution"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups",
          "scheduler:CreateSchedule",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "iam:PassRole",
        ],
        Effect   = "Allow",
        Resource = "*",
      },
      {
        Action = "events:PutRule",
        Effect = "Allow",
        Resource = "*",
      },
      {
        Action = "events:PutTargets",
        Effect = "Allow",
        Resource = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_cognito_user_pool" "user_pool" {
  name = "star-lord-user-pool"

  # Add additional settings if needed
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain      = var.cognito_domain
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "star-lord-user-pool-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  generate_secret     = true


  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["phone", "email", "openid", "profile", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls = ["${aws_apigatewayv2_api.api.api_endpoint}${var.callback_path}"]

  # Ensure this is the correct value for your setup
  supported_identity_providers = ["COGNITO"]
}

resource "aws_lambda_function" "allow_access" {
  filename         = "allow_access.zip"
  function_name    = "allow_access"
  role             = aws_iam_role.lambda_role.arn
  handler          = "allow_access.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("allow_access.zip")

  environment {
    variables = {
      STAR_LORD_SECURITY_GROUP_ID     = var.security_group_id
      STAR_LORD_SECURITY_GROUP_REGION = var.security_group_region
      STAR_LORD_PORT                  = var.port
      STAR_LORD_EXPIRATION_TIME       = var.expiration_time
      STAR_LORD_LOG_GROUP_NAME        = var.log_group_name_allow_access
      STAR_LORD_AWS_REGION            = var.region
      STAR_LORD_COGNITO_USER_POOL_ID  = aws_cognito_user_pool.user_pool.id
      STAR_LORD_COGNITO_DOMAIN        = var.cognito_domain
      STAR_LORD_COGNITO_CLIENT_ID     = aws_cognito_user_pool_client.user_pool_client.id
      STAR_LORD_COGNITO_CLIENT_SECRET = aws_cognito_user_pool_client.user_pool_client.client_secret
      STAR_LORD_CALLBACK_URL          = "${aws_apigatewayv2_api.api.api_endpoint}${var.callback_path}"
      STAR_LORD_CALLBACK_URL          = "${aws_apigatewayv2_api.api.api_endpoint}${var.callback_path}"
      STAR_LORD_ROLE_ARN = aws_iam_role.lambda_role.arn
      STAR_LORD_REVOKE_LAMBDA_ARN = aws_lambda_function.revoke_access.arn
    }
  }
}

resource "aws_lambda_function" "revoke_access" {
  filename         = "revoke_access.zip"
  function_name    = "revoke_access"
  role             = aws_iam_role.lambda_role.arn
  handler          = "revoke_access.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("revoke_access.zip")

  environment {
    variables = {
      STAR_LORD_LOG_GROUP_NAME = var.log_group_name_revoke_access
      STAR_LORD_SECURITY_GROUP_REGION = var.security_group_region
    }
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.allow_access.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_api" "api" {
  name          = "star-lord-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.allow_access.arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /allow_access"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id          = aws_apigatewayv2_api.api.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name            = "CognitoAuthorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.user_pool_client.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
  }
}

resource "aws_cloudwatch_log_group" "allow_access_log" {
  name              = var.log_group_name_allow_access
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "revoke_access_log" {
  name              = var.log_group_name_revoke_access
  retention_in_days = 14
}
