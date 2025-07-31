provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "ecs_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ecs-vpc"
    Environment = "dev"
  }
}

# Subnet
resource "aws_subnet" "ecs_subnet" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ecs-subnet"
    Environment = "dev"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "ecs-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ecs-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.ecs_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
    Environment = "dev"
  }
}

# ECR Repository
resource "aws_ecr_repository" "myapp_repo" {
  name                 = "myapp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# IAM Role
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy Attachment
resource "aws_iam_role_policy_attachment" "ecs_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-lt-"
  image_id      = "ami-0c58430228056d84e"
  instance_type = "t2.micro"
  key_name      = "shaazil"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    device_index                = 0
    subnet_id                   = aws_subnet.ecs_subnet.id
    security_groups             = [aws_security_group.ecs_sg.id]
  }

  tags = {
    Name = "ecs-launch-template"
    Environment = "dev"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix               = "ecs-asg-"
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.ecs_subnet.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  wait_for_capacity_timeout = "0"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "dev"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "myapp_task" {
  family                   = "my-app-task-def"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "myapp-container"
    image     = "940482417774.dkr.ecr.us-east-1.amazonaws.com/myapp:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.myapp_task.arn
  launch_type     = "EC2"
  desired_count   = 1
  force_new_deployment = true
  propagate_tags  = "SERVICE"

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_autoscaling_group.ecs_asg,
    aws_ecs_task_definition.myapp_task
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Scale down ECS service before destroy
resource "null_resource" "scale_down_service" {
  provisioner "local-exec" {
    command = <<EOT
      aws ecs update-service \
        --cluster ${aws_ecs_cluster.ecs_cluster.name} \
        --service ${aws_ecs_service.ecs_service.name} \
        --desired-count 0
    EOT
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [aws_ecs_service.ecs_service]
}

# Output
output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}

