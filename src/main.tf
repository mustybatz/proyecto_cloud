terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = "us-west-2"
  profile = "cloud"
}

resource "aws_vpc" "main" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_a" {
  cidr_block        = "192.168.1.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "public_b" {
  cidr_block        = "192.168.2.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-west-2b"
}

resource "aws_subnet" "private_a" {
  cidr_block        = "192.168.3.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "private_b" {
  cidr_block        = "192.168.4.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-west-2b"
}

resource "aws_eip" "nat_a" {
  vpc = true
}

resource "aws_eip" "nat_b" {
  vpc = true
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_key_pair" "test-pair" {
  key_name   = "cloud"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
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

resource "aws_security_group" "server" {
  name        = "server"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow traffic from ALB"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
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
}





resource "aws_security_group" "backend-rds" {
  name        = "backend-rds"
  description = "Allow RDS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.server.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "backend-rds" {
  db_subnet_group_name   = aws_db_subnet_group.backend-rds.name
  db_name                = "backend"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = "motomami"
  parameter_group_name   = "default.mysql5.7"
  allocated_storage      = 30
  vpc_security_group_ids = [aws_security_group.backend-rds.id]
  skip_final_snapshot    = true
}


resource "aws_instance" "bastion_server" {
  ami                         = "ami-0854e54abaeae283b"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  associate_public_ip_address = true
  key_name                    = "cloud"
  security_groups             = [aws_security_group.server.id]

  user_data = file("./scripts/bastion.sh")


  depends_on = [
    aws_security_group.server
  ]
}

data "template_file" "user_data" {
  template = file("./scripts/user-data.tpl")

  vars = {
    rds_hostname = aws_db_instance.backend-rds.address
  }

}

resource "aws_launch_configuration" "backend" {
  name_prefix     = "node-"
  image_id        = "ami-0854e54abaeae283b"
  instance_type   = "t2.micro"
  user_data       = data.template_file.user_data.rendered
  security_groups = [aws_security_group.server.id]
  key_name        = "cloud"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "backend" {
  name                 = "backend"
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.backend.name
  vpc_zone_identifier  = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tag {
    key                 = "Name"
    value               = "Backend Server"
    propagate_at_launch = true
  }
}

resource "aws_lb" "backend" {
  name               = "backend-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_target_group" "backend" {
  name     = "backend"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}


resource "aws_autoscaling_attachment" "backend" {
  autoscaling_group_name = aws_autoscaling_group.backend.id
  alb_target_group_arn   = aws_lb_target_group.backend.arn
}

resource "aws_db_subnet_group" "backend-rds" {
  name       = "backend-rds"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
