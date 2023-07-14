provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "us-west-2"
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.test]
}

# Create EIP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_internet_gateway" "test" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "test-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "public_internet_gateway_route_1" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test.id

}

resource "aws_route" "public_internet_gateway_route_2" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test.id

}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "private-subnet-2"
  }
}

# Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "private_nat_gateway_route_1" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id

}
# Route Table Association
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name        = "alb-security-group"
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_alb" {
  name               = "AppALB"
  internal           = false 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "app_target_group" {
  name        = "App"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"
}

resource "aws_lb_target_group" "purchase_target_group" {
  name        = "Purchase"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"
}

# Create ALB Listeners

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service is unavailable at the moment."
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
 

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}
# Define ALB Rules to map API paths to Target Groups
resource "aws_lb_listener_rule" "save_purchase_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.purchase_target_group.arn
  }

  condition {
    path_pattern {
      values = ["api/save_purchase"]
    }
  }
}

resource "aws_lb_listener_rule" "get_purchase_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.purchase_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/get_purchases"]
    }
  }
}

resource "aws_lb_listener_rule" "send_sms_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/sms"]
    }
  }
}

resource "aws_lb_listener_rule" "send_call_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 4

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/call_customer"]
    }
  }
}

resource "aws_lb_listener_rule" "app_entry_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/"] # for the index.html
    }
  }
}

# create s3 bucket for html file
resource "aws_s3_bucket" "purchase_form" {
  bucket = "purchase4ormdhanyalproj"
}
resource "aws_s3_bucket_policy" "access" {
  bucket = aws_s3_bucket.purchase_form.id
  policy = <<POLICY
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::purchase4ormdhanyalproj/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.purchase_form.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.purchase_form.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.purchase_form.id
  acl    = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "example" {
  bucket = aws_s3_bucket.purchase_form.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
resource "aws_api_gateway_rest_api" "my_rest_api" {
  name        = "myrestapi"
  description = "My REST API"
}

# Create API Gateway Methods and Integrations for each endpoint
resource "aws_api_gateway_resource" "save_purchase_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  parent_id   = aws_api_gateway_rest_api.my_rest_api.root_resource_id
  path_part   = "save_purchase"
}

resource "aws_api_gateway_method" "save_purchase_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_rest_api.id
  resource_id   = aws_api_gateway_resource.save_purchase_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "save_purchase_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_rest_api.id
  resource_id             = aws_api_gateway_resource.save_purchase_resource.id
  http_method             = aws_api_gateway_method.save_purchase_method.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.app_alb.dns_name}/purchase/api/save_purchase"
}

resource "aws_api_gateway_method_response" "save_purchase_method_response" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.save_purchase_resource.id
  http_method = aws_api_gateway_method.save_purchase_method.http_method
  status_code = "200"
}


resource "aws_api_gateway_resource" "get_purchases_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  parent_id   = aws_api_gateway_rest_api.my_rest_api.root_resource_id
  path_part   = "get_purchases"
}

resource "aws_api_gateway_method" "get_purchases_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_rest_api.id
  resource_id   = aws_api_gateway_resource.get_purchases_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_purchases_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_rest_api.id
  resource_id             = aws_api_gateway_resource.get_purchases_resource.id
  http_method             = aws_api_gateway_method.get_purchases_method.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.app_alb.dns_name}/purchase/api/get_purchases"
}

resource "aws_api_gateway_method_response" "get_purchases_method_response" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.get_purchases_resource.id
  http_method = aws_api_gateway_method.get_purchases_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_resource" "send_sms_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  parent_id   = aws_api_gateway_rest_api.my_rest_api.root_resource_id
  path_part   = "send_sms"
}

resource "aws_api_gateway_method" "send_sms_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_rest_api.id
  resource_id   = aws_api_gateway_resource.send_sms_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "send_sms_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_rest_api.id
  resource_id             = aws_api_gateway_resource.send_sms_resource.id
  http_method             = aws_api_gateway_method.send_sms_method.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.app_alb.dns_name}/purchase/api/send_sms"
}

resource "aws_api_gateway_method_response" "send_sms_method_response" {
  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.send_sms_resource.id
  http_method = aws_api_gateway_method.send_sms_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_deployment" "my_deployment" {
  depends_on = [
    aws_api_gateway_integration.save_purchase_integration,
    aws_api_gateway_method_response.save_purchase_method_response,
    aws_api_gateway_integration.get_purchases_integration,
    aws_api_gateway_method_response.get_purchases_method_response,
    aws_api_gateway_integration.send_sms_integration,
    aws_api_gateway_method_response.send_sms_method_response
  ]

  rest_api_id = aws_api_gateway_rest_api.my_rest_api.id
  stage_name  = "test"
}

# Create security group for EC2 instances
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main_vpc.id
  name        = "ecs-security-group"
  description = "Security group for ECS instances"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "tags-cluster"
}

# Create ECS service for App Microservice
resource "aws_ecs_service" "app_service" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app_task_definition.arn
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = "app-container"
    container_port   = 5000
  }
}

# Create ECS service for Purchase Microservice
resource "aws_ecs_service" "purchase_service" {
  name            = "purchase-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.purchase_task_definition.arn
  desired_count   = 1

  network_configuration {
    subnets         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.purchase_target_group.arn
    container_name   = "purchase-container"
    container_port   = 5001
  }
}

# Create ECS task definition for App Microservice
resource "aws_ecs_task_definition" "app_task_definition" {
  family                   = "app-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      "name": "app-container",
      "image": "public.ecr.aws/i2q4j1g4/ecr-cow-dashboard:latest",#${aws_ecr_repository.app_repo.repository_url}:latest
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000,
          "protocol": "tcp"
        }
      ]
    }
  ])
}

# Create ECS task definition for Purchase Microservice
resource "aws_ecs_task_definition" "purchase_task_definition" {
  family                   = "purchase-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      "name": "purchase-container",
      "image": "public.ecr.aws/c7l4l0y6/helloword-yarden:latest", #${aws_ecr_repository.purchase_repo.repository_url}:latest
      "portMappings": [
        {
          "containerPort": 5001,
          "hostPort": 5001,
          "protocol": "tcp"
        }
      ]
    }
  ])
}

# IAM Roles for ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# ECS Task Execution Role Policies
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role Policies
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment_3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment_5" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.ecs_task_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment_6" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.ecs_task_role.name
}