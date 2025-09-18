########################################
# Terraform + Provider
########################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

locals {
  region         = "us-east-1"
  cluster_name   = "gameshow-cluster"
  repo_name      = "gameshow-backend"
  container_port = 5004
  instance_type  = "t3.micro"                
  log_group      = "/ecs/gameshow-backend"
}

provider "aws" {
  region = local.region
}

########################################
# IAM: roles needed for ECS on EC2
########################################

# Task Execution Role (pulls from ECR, writes CloudWatch Logs)
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# EC2 Instance Role (lets the container instance register with ECS)
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_managed" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# Allow SSM Session Manager on the EC2 container instance
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "gameshow-backend-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}


########################################
# Networking: use default VPC + SG
########################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_instance_sg" {
  name        = "gameshow-ecs-ec2-sg"
  description = "Allow HTTP(5004) and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App port"
    from_port   = local.container_port
    to_port     = local.container_port
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

########################################
# ECS Cluster
########################################
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name
}

########################################
# EC2 container instance (ECS-optimized AMI)
########################################
data "aws_ami" "ecs_optimized" {
  owners = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "ecs_container_instance" {
  ami                         = data.aws_ami.ecs_optimized.id
  instance_type               = local.instance_type
  subnet_id                   = data.aws_subnets.default_vpc_subnets.ids[0]
  vpc_security_group_ids      = [aws_security_group.ecs_instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${local.cluster_name}" >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "GameshowECSInstance"
  }
}

########################################
# Logs
########################################
resource "aws_cloudwatch_log_group" "app" {
  name              = local.log_group
  retention_in_days = 3
}

########################################
# ECR repo (for image URI)
########################################
data "aws_ecr_repository" "repo" {
  name = local.repo_name
}
########################################
# Variables for cors_origion
########################################

# variables.tf (or at top of ecs main.tf)
variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin for the backend"
  default     = "*"   
}

########################################
# ECS Task Definition (bridge networking)
########################################
resource "aws_ecs_task_definition" "backend" {
  family                   = "gameshow-backend-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "gameshow-backend"
      image     = "${data.aws_ecr_repository.repo.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp" }
      ]
      environment = [
        { name = "PORT",          value = tostring(local.container_port) },
        { name = "MONGODB_URI",   value = "mongodb+srv://SBNAadmin:8PYSMXyZ%40zp4uwF@cluster1-production.v4anhjy.mongodb.net" },
        { name = "DB_NAME",       value = "Data_Scored_Test" },
        { name = "JWT_SECRET",  value = "seceretkey" },
        { name = "REACT_APP_API_KEY",  value = "H0ylHQmpyATxhhRUV3iMEfQnq1xkZl0uUGN9g26OubSw6Od5H0XwKGCMJhaY7TwL"},
        { name  = "CORS_ORIGIN", value = var.cors_origin}
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = local.region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

########################################
# ECS Service (1 task on the EC2 instance)
########################################
resource "aws_ecs_service" "svc" {
  name            = "gameshow-backend-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "EC2"
  enable_execute_command = true
  deployment_minimum_healthy_percent = 0
  force_delete                       = true  

  depends_on = [aws_instance.ecs_container_instance]
}

########################################
# Helpful outputs
########################################
output "ec2_public_ip" {
  value = aws_instance.ecs_container_instance.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.ecs_container_instance.public_dns
}

output "hit_app_here" {
  value = "http://${aws_instance.ecs_container_instance.public_dns}:${local.container_port}"
}

