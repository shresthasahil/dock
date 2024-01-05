# terraform file only for ECS cluster setup
# doesnot setup Cluster itself

provider "aws" {
  region = "us-east-2"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token = var.AWS_SESSION_TOKEN
}


resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.alb_sg.id ]
  subnets            = [ aws_subnet.ecs_public_subnet_a.id, aws_subnet.ecs_public_subnet_b.id ]
}

resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-cluster-tg"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.ecs_vpc.id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

#VPC
resource "aws_vpc" "ecs_vpc" {
  cidr_block       = "10.0.0.0/24"

  tags = {
    Name = "ecs_vpc"
  }
}

#Public Subnet
resource "aws_subnet" "ecs_public_subnet_a" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-2a"
  cidr_block = "10.0.0.0/26"

  tags = {
    Name = "ecs_public_subnet_a"
  }
}

#Private Subnet
resource "aws_subnet" "ecs_private_subnet_a" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-2a"
  cidr_block = "10.0.0.64/26"

  tags = {
    Name = "ecs_private_subnet_a"
  }
}

#Public Subnet
resource "aws_subnet" "ecs_public_subnet_b" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-2b"
  cidr_block = "10.0.0.128/26"

  tags = {
    Name = "ecs_public_subnet_b"
  }
}

#Private Subnet
resource "aws_subnet" "ecs_private_subnet_b" {
  vpc_id     = aws_vpc.ecs_vpc.id
  availability_zone = "us-east-2b"
  cidr_block = "10.0.0.192/26"

  tags = {
    Name = "ecs_private_subnet_b"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "ecs_igw"
  }
}

#NAT_Gateway
resource "aws_eip" "nat_gateway" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id = aws_subnet.ecs_public_subnet_a.id
  tags = {
    "Name" = "nat_gateway"
  }

    depends_on = [aws_internet_gateway.internet_gateway, aws_eip.nat_gateway]
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

#Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ecs_vpc.id

  # local automatically configured

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "ecs_public_rt"
  }
}

#Routing tables to route traffic for Private Subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.ecs_vpc.id

  # local automatically configured

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "ecs_private_rt"
  }
}

resource "aws_route_table_association" "public-rta" {
  subnet_id = aws_subnet.ecs_public_subnet_a.id 
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private-rta" {
  subnet_id = aws_subnet.ecs_private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "public-rtb" {
  subnet_id = aws_subnet.ecs_public_subnet_b.id 
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private-rtb" {
  subnet_id = aws_subnet.ecs_private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

#Security Group for Load Balancer 
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP traffic from anywhere inside Load Balancer"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
   }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb_sg"
  }
}

#Security Group for Bastion Host 
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow all traffics from Load Balancer and Bastion Host SG"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    description      = "SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "bastion_sg"
  }
}

#Security Group for ECS Cluster 
resource "aws_security_group" "ecs_cluster" {
  name        = "ecs_cluster"
  description = "Allow all traffics from Load Balancer and Bastion Host SG"
  vpc_id      = aws_vpc.ecs_vpc.id

  ingress {
    description      = "incoming traffic only from ALB"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups  = [aws_security_group.alb_sg.id]
  }

  ingress {
    description      = "incoming SSH only from ALB"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }

  depends_on = [aws_security_group.alb_sg, aws_security_group.bastion_sg]
}
