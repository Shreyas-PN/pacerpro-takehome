terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


resource "aws_sns_topic" "pacerpro_alerts" {
  name = "pacerpro-alerts-terraform"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.pacerpro_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


resource "aws_instance" "pacerpro_ec2" {
  ami           = "ami-0c02fb55956c7d316" 
  instance_type = "t3.micro"

  tags = {
    Name = "pacerpro-terraform-instance"
  }
}


resource "aws_iam_role" "lambda_role" {
  name = "pacerpro-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_ec2" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_function" "pacerpro_lambda" {
  function_name = "pacerpro-terraform-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  filename         = "../lambda_function/lambda.zip"
  source_code_hash = filebase64sha256("../lambda_function/lambda.zip")

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.pacerpro_ec2.id
      SNS_TOPIC_ARN = aws_sns_topic.pacerpro_alerts.arn
    }
  }
}
