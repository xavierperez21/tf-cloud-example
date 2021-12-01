terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      // version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  // access_key = "ASIA5C23C6RDXPMNDX5T"
  // secret_key = "JjGJH2raY1pdGPxU5sNW97lEgwhue+OWhSNvS/Z+"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.88.0.0/16"

  tags = {
    Name = "lxpm-vpc-tf"
  }
}

# Subnet connected to previous VPC
resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.88.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "lxpm-subnet-tf"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "luis-igw"
  }
}

# Public route table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "luis-route-table-public"
  }
}

# Associate public subnet to public route table
resource "aws_route_table_association" "my_route_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

variable "sg_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [8200, 8201, 8300, 9200, 9500, 443]
}

resource "aws_security_group" "dynamic-sg" {
  name        = "lxpm-sg-dynamic"
  description = "Ingress for Vault"
  vpc_id      = aws_vpc.my_vpc.id

  dynamic "ingress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = var.sg_ports
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

data "aws_ami" "app_ami" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["amzn2-ami-hvm*"]
    }
}

resource "aws_instance" "dev" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_subnet.id
  associate_public_ip_address = true
  security_groups             = [aws_security_group.dynamic-sg.id]
}