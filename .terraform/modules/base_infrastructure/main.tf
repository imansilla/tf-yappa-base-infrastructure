#DHCP Option Set
resource "aws_vpc_dhcp_options" "main" {
  domain_name         = "ec2.internal"
  domain_name_servers = [
    "AmazonProvidedDNS"]

  tags = merge(local.common_tags, {
    Name = "Brain_DHCP"
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "Brain_VPC"
  })
}

# VPC and DHCP_Option Association
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}

## Public Subnet 1a
resource "aws_subnet" "public1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "Brain_Public_1a"
  })
}

# Private Subnet 1a
resource "aws_subnet" "private1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"

  tags = merge(local.common_tags, {
    Name = "Brain_Private_1a"
  })
}

# Public Subnet 1b
resource "aws_subnet" "public1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "Brain_Public_1b"
  })
}

## Private Subnet 1b
resource "aws_subnet" "private1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "Brain_Private_1b"
  })
}

#Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "Brain_IGW"
  })
}

#EIP for NAT Gateway
resource "aws_eip" "nat" {
  vpc = true

  tags = merge(local.common_tags, {
    Name = "Brain_NAT_GW_EIP"
  })
}

#NAT Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1a.id

  tags = merge(local.common_tags, {
    Name = "Brain_NGW"
  })
}

#Route Table for Public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "Brain_PublicSubnetsRouteTable"
  })
}

#Route table association for Public subnets
resource "aws_route_table_association" "public1b" {
  subnet_id      = aws_subnet.public1b.id
  route_table_id = aws_route_table.public.id
}

#Route table association for Public subnets
resource "aws_route_table_association" "public1a" {
  subnet_id      = aws_subnet.public1a.id
  route_table_id = aws_route_table.public.id
}

#Route Table for Private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = merge(local.common_tags, {
    Name = "Brain_PrivateSubnetsRouteTable"
  })
}

#Route table association for Public subnets
resource "aws_route_table_association" "private1a" {
  subnet_id      = aws_subnet.private1a.id
  route_table_id = aws_route_table.private.id
}

#Route table association for Public subnets
resource "aws_route_table_association" "private1b" {
  subnet_id      = aws_subnet.private1b.id
  route_table_id = aws_route_table.private.id
}

#Role for ecs task execution
resource "aws_iam_role" "ecs_tasks_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_execution_role.json
}

#Policy attachment to ecsTaskExecutionRole
resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = aws_iam_role.ecs_tasks_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#Linked Role for ECS Service
resource "aws_iam_service_linked_role" "AWSServiceRoleForECS" {
  aws_service_name = "ecs.amazonaws.com"
  description      = "Role to enable Amazon ECS to manage your cluster."
}

#Security group for ALB
resource "aws_security_group" "allow_http" {
  name        = "alb01-brain-sg"
  description = "Allow http inbound traffic for alb01-brain"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP access to alb"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access to alb"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  #allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = local.common_tags

}

resource "aws_lb" "alb" {
  name               = "alb01-brain"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [
    aws_security_group.allow_http.id]
  subnets            = data.aws_subnet_ids.selected.ids

  enable_deletion_protection = false

  tags = local.common_tags
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.brain-gbuniversity-com.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

/*
#S3 Bucket for artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket  = var.S3Bcuket_codepipeline
  acl     = "private"
  policy  = data.aws_iam_policy_document.S3Bucket-BasePolicy.json
  tags    = local.common_tags
}
*/

#Security group for VPC Endpoints
resource "aws_security_group" "vpce_ecr_sg" {
  name        = "vpce-ecr-sg"
  description = "Allow access traffic for vpc endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  #allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = local.common_tags

}

#VPCE for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [ aws_route_table.private.id ]

  tags = merge(local.common_tags, {
    Name = "vpce_s3"
  })
}

#VPCE for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "${aws_security_group.vpce_ecr_sg.id}",
  ]

  subnet_ids          = data.aws_subnet_ids.private.ids
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "vpce_ecr_api"
  })
}

#VPCE for ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "${aws_security_group.vpce_ecr_sg.id}",
  ]

  subnet_ids          = data.aws_subnet_ids.private.ids
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "vpc_ecr_dkr"
  })
}

#VPCE for CLOUDWATCH LOGS
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    "${aws_security_group.vpce_ecr_sg.id}",
  ]

  subnet_ids          = data.aws_subnet_ids.private.ids
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "vpc_cloudwatch_logs"
  })
}