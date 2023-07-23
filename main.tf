# Specify the AWS provider
provider "aws" {
  region = "us-west-2" # Change this to your preferred AWS region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" # Update CIDR block as per your requirements
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24" # Update CIDR block as per your requirements
  map_public_ip_on_launch = true 
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24" # Update CIDR block as per your requirements
}

# Create an internet gateway and attach it to our VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Create a route table for the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate the public subnet with the route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group to allow web traffic
resource "aws_security_group" "web" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# Create an RDS instance in the private subnet
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "dbname"
  username             = "admin"
  password             = "adminpassword" # Do not hardcode passwords in production environments
  parameter_group_name = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible = false
  subnet_group_name = aws_db_subnet_group.default.name
  multi_az = true # Enable Multi-AZ for high availability
}

# Create a subnet group for RDS instance
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private.id]

  tags = {
    Name = "My DB subnet group"
  }
}

# Create a launch configuration
resource "aws_launch_configuration" "example" {
  image_id      = "ami-0c94855ba95c574c8" # Update to a valid AMI ID
  instance_type = "t2.micro"
  security_groups = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, world!" > index.html
              nohup busybox httpd -f -p 80 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

# Create an Auto Scaling group
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.public.id]
}

# Output the public DNS of the Load Balancer
output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}
