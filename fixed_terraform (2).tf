provider "aws" {
  region = "us-east-1"
}

# Data source to dynamically fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# A basic VPC to host the security group and instances
# In a real-world scenario, you might use an existing VPC via a data source
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_instance" "web_server" {
  # Use the dynamically fetched AMI ID for security and updates
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"

  tags = {
    Name        = "web-server"
    Environment = "dev"
  }

  # Use a specific, securely managed key_name (or remove if using Session Manager)
  key_name = "mykeypair-secure"
  # For production environments, consider using AWS Systems Manager Session Manager
  # or an instance profile with IAM roles for access, removing the need for SSH key pairs.

  # Use vpc_security_group_ids and reference by ID, not name (best practice)
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Ensure count is an integer, not a string
  count = 2
}

resource "aws_security_group" "web_sg" {
  name        = "web_sg_secured"
  description = "Security group for web server with restricted access"
  vpc_id      = aws_vpc.main.id # Link to the VPC

  # Ingress rule: Restrict SSH access (port 22) to a specific, trusted IP range.
  # IMPORTANT: Replace "192.0.2.0/32" with your actual secure management IP range (e.g., your workstation's public IP /32, or corporate VPN CIDR).
  # Allowing 0.0.0.0/0 for SSH is HIGHLY INSECURE and defeats the purpose of the fix.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.0.2.0/32"] 
    description = "Allow SSH from specific management IP"
  }

  # For a public web server, you would typically place it behind an Application Load Balancer (ALB).
  # The ALB's security group would then allow HTTP/S from 0.0.0.0/0, and this instance's SG
  # would only allow HTTP/S from the ALB's security group.
  # Example for ALB integration (commented out as ALB is not in this code):
  # ingress {
  #   from_port       = 80
  #   to_port         = 80
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb_sg.id] # Reference ALB's security group
  #   description     = "Allow HTTP from ALB"
  # }

  # Egress rule: Restrict outbound traffic to only necessary ports and protocols.
  # Allowing HTTPS (443) for updates, API calls, etc.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound HTTPS to anywhere (e.g., for updates/APIs)
    description = "Allow outbound HTTPS"
  }

  # If DNS resolution is required, allow UDP/TCP port 53 outbound.
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound DNS (UDP)"
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound DNS (TCP)"
  }
}