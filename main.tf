provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}
data "archive_file" "lambda-functions" {
  type        = "zip"
  source_dir  = "./Lambda-Functions"
  output_path = "./Lambda-Functions.zip"
}

### SES ###

resource "aws_ses_email_identity" "email" {
  email = "ahmedbrimawi@gmail.com"
}
### Policy ###
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole",
    ]
  }
}
data "aws_iam_policy_document" "DynamoDB" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "ses:SendEmail"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = "${aws_iam_role.ec2_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "assume_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_lambda.name
}
resource "aws_iam_role" "iam_for_lambda" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "IAMPolicyforDynamoDB"
}
resource "aws_iam_policy_attachment" "DynamoDB" {
  name       = "IAMPolicyforDynamoDB"
  policy_arn = aws_iam_policy.DynamoDB.arn
  roles      = [aws_iam_role.iam_for_lambda.name]
}
resource "aws_iam_policy" "DynamoDB" {
  name   = "IAMPolicyforDynamoDB"
  policy = data.aws_iam_policy_document.DynamoDB.json
}

### lambda ###

resource "aws_lambda_function" "lambda-courier_management" {
  function_name    = "courier_management"
  filename         = data.archive_file.lambda-functions.output_path
  source_code_hash = data.archive_file.lambda-functions.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "courier_management.lambda_handler"
  runtime          = "python3.9"
}
resource "aws_lambda_function" "lambda-shipment_management" {
  function_name    = "shipment_management"
  filename         = data.archive_file.lambda-functions.output_path
  source_code_hash = data.archive_file.lambda-functions.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "shipment_management.lambda_handler"
  runtime          = "python3.9"
}
resource "aws_lambda_function" "lambda-manual_attach" {
  function_name    = "manual_attach"
  filename         = data.archive_file.lambda-functions.output_path
  source_code_hash = data.archive_file.lambda-functions.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "manual_attach.lambda_handler"
  runtime          = "python3.9"
}
resource "aws_lambda_function" "lambda-email_notification" {
  function_name    = "email_notification"
  filename         = data.archive_file.lambda-functions.output_path
  source_code_hash = data.archive_file.lambda-functions.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "email_notification.lambda_handler"
  runtime          = "python3.9"
}

### Gateway ###

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}
resource "aws_apigatewayv2_stage" "lambda" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "serverless_lambda_stage"
  auto_deploy = true
}

### Integrattion ###

# courier_management
resource "aws_apigatewayv2_integration" "courier_management" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda-courier_management.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST" # REST API communication between API Gateway and Lambda
}
resource "aws_apigatewayv2_route" "courier_management" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "ANY /courier_management" #accept ANY method (get, post...)
  target    = "integrations/${aws_apigatewayv2_integration.courier_management.id}"
}

# shipment_management
resource "aws_apigatewayv2_integration" "shipment_management" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda-shipment_management.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST" # REST API communication between API Gateway and Lambda
}
resource "aws_apigatewayv2_route" "shipment_management" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "ANY /shipment_management"
  target    = "integrations/${aws_apigatewayv2_integration.shipment_management.id}"
}

# manual_attach
resource "aws_apigatewayv2_integration" "manual_attach" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda-manual_attach.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST" # REST API communication between API Gateway and Lambda
}
resource "aws_apigatewayv2_route" "manual_attach" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "ANY /manual_attach"
  target    = "integrations/${aws_apigatewayv2_integration.manual_attach.id}"
}

#SES
resource "aws_apigatewayv2_integration" "email_notification" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda-email_notification.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST" # REST API communication between API Gateway and Lambda
}
resource "aws_apigatewayv2_route" "email_notification" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "ANY /email_notification" #accept ANY method (get, post...)
  target    = "integrations/${aws_apigatewayv2_integration.email_notification.id}"
}

### Lambda Permission ###

resource "aws_lambda_permission" "courier_management" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-courier_management.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api_gw_shipment_management" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-shipment_management.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api_gw_manual_attach" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-manual_attach.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api_gw_email_notification" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-email_notification.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

### Creating table ###

resource "aws_dynamodb_table" "courier_management" {
  name           = "courier_management"
  billing_mode   = "PROVISIONED"
  read_capacity  = "5"
  write_capacity = "5"
  hash_key       = "ID"
  attribute {
    name = "ID"
    type = "N" #int
  }
}
resource "aws_dynamodb_table" "shipment_management" {
  name           = "shipment_management"
  billing_mode   = "PROVISIONED"
  read_capacity  = "5"
  write_capacity = "5"
  hash_key       = "ID"
  attribute {
    name = "ID"
    type = "N" #int
  }
}
resource "aws_dynamodb_table" "result" {
  name           = "result"
  billing_mode   = "PROVISIONED"
  read_capacity  = "5"
  write_capacity = "5"
  hash_key       = "PackageID"
  attribute {
    name = "PackageID"
    type = "N" #int
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id


}


resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true


  tags = {
    Name = "main_subnet"
  }
}

resource "aws_route_table" "public-route-table" {
vpc_id       = aws_vpc.main.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
}
tags       = {
Name     = "Public Route Table"
}
}

resource "aws_route_table_association" "public-subnet-1-route-table-association" {
subnet_id           = aws_subnet.my_subnet.id
route_table_id      = aws_route_table.public-route-table.id
}


resource "aws_instance" "infraserver" {
  ami           = "ami-0b5eea76982371e91"
  instance_type = "t2.micro"
  subnet_id   = aws_subnet.my_subnet.id
  associate_public_ip_address = true
  key_name = "cx-project"
  vpc_security_group_ids = ["${aws_security_group.sec_group.id}"]

  tags = {
    Name = "InfraServer"
  }

  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.name}"

  
    provisioner "file" {
        source      = "Server-Files/apigt.go"
        destination = "/home/ec2-user/apigt.go"

        connection {
            type        = "ssh"
            user        = "ec2-user"
            private_key = file("cx-project.pem")
            host        = self.public_ip
        }
    }

      provisioner "file" {
        source      = "Server-Files/go.mod"
        destination = "/home/ec2-user/go.mod"

        connection {
            type        = "ssh"
            user        = "ec2-user"
            private_key = file("cx-project.pem")
            host        = self.public_ip
        }
    }

      provisioner "file" {
        source      = "Server-Files/go.sum"
        destination = "/home/ec2-user/go.sum"

        connection {
            type        = "ssh"
            user        = "ec2-user"
            private_key = file("cx-project.pem")
            host        = self.public_ip
        }
    }


provisioner "remote-exec" {
        inline = [
            "sudo yum install golang -y",
            "go build apigt.go",
        ]

        connection {
            type        = "ssh"
            user        = "ec2-user"
            private_key = file("cx-project.pem")
            host        = self.public_ip
        }
    }

}


resource "aws_security_group" "sec_group" {
  vpc_id=aws_vpc.main.id
  name = "sec_group"
    ingress {
        from_port        = 22
        to_port          = 22
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

       ingress {
        from_port        = 443
        to_port          = 443
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


