# FoundryDeploy AWS EC2 Terraform Module
# Deploys a Foundry VTT server on AWS EC2

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Data source for latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC (use default or create new based on variable)
data "aws_vpc" "default" {
  count   = var.create_vpc ? 0 : 1
  default = true
}

resource "aws_vpc" "foundry" {
  count      = var.create_vpc ? 1 : 0
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

locals {
  vpc_id = var.create_vpc ? aws_vpc.foundry[0].id : data.aws_vpc.default[0].id
}

# Subnet
data "aws_subnets" "default" {
  count = var.create_vpc ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

resource "aws_subnet" "foundry" {
  count                   = var.create_vpc ? 1 : 0
  vpc_id                  = local.vpc_id
  cidr_block              = var.subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-subnet"
  })
}

locals {
  subnet_id = var.create_vpc ? aws_subnet.foundry[0].id : data.aws_subnets.default[0].ids[0]
}

# Internet Gateway (only if creating VPC)
resource "aws_internet_gateway" "foundry" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = local.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Route Table (only if creating VPC)
resource "aws_route_table" "foundry" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.foundry[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rt"
  })
}

resource "aws_route_table_association" "foundry" {
  count          = var.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.foundry[0].id
  route_table_id = aws_route_table.foundry[0].id
}

# Security Group
resource "aws_security_group" "foundry" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for Foundry VTT server"
  vpc_id      = local.vpc_id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  # HTTP (for redirect to HTTPS)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS (main Foundry access)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-sg"
  })
}

# Read cloud-init user data
locals {
  user_data = file("${path.module}/../cloud-init.yaml")
}

# EC2 Instance
resource "aws_instance" "foundry" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.foundry.id]
  associate_public_ip_address = true
  user_data                   = local.user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Enable detailed monitoring if requested
  monitoring = var.enable_monitoring

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-server"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP (optional)
resource "aws_eip" "foundry" {
  count    = var.create_elastic_ip ? 1 : 0
  instance = aws_instance.foundry.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eip"
  })
}

# Computed values for outputs
locals {
  # Use try() to safely handle case when EIP count is 0
  instance_public_ip = try(aws_eip.foundry[0].public_ip, aws_instance.foundry.public_ip)
}
