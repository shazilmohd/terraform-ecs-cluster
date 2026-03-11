variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "AMI ID for ECS EC2 instances"
  type        = string
  default     = "ami-0c58430228056d84" # change to latest marketplace AMI for ECS or use aws_ami data source
}

variable "instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Optional SSH key name for EC2 instances"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment tag value"
  type        = string
  default     = "dev"
}

variable "allowed_ingress_cidr" {
  description = "CIDR block allowed for inbound (replace 0.0.0.0/0 in production)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "my-ecs-cluster"
}

variable "service_name" {
  description = "ECS service name"
  type        = string
  default     = "myapp-service"
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
  default     = 80
}

variable "image_uri" {
  description = "ECR image URI to run in ECS task"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "Prefix for VPC naming"
  type        = string
  default     = "ecs-vpc"
}

variable "asg_min_size" {
  description = "ASG min size"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "ASG max size"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 1
}
