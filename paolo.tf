/*----------------------------------------------------------------------*/
/* Shared VPC                                                           */
/*----------------------------------------------------------------------*/

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "yappa-app"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
  public_subnets  = ["10.0.64.0/20", "10.0.80.0/20", "10.0.96.0/20"]

  enable_nat_gateway      = true
  one_nat_gateway_per_az  = true

  enable_dns_hostnames    = true
  enable_dns_support      = true

  enable_s3_endpoint      = false
  enable_ecr_api_endpoint = false
  enable_ecr_dkr_endpoint = false

  private_subnet_tags = {Tier = "Private"}
  public_subnet_tags  = {Tier = "Public"}
  tags = var.common_tags
}

/*----------------------------------------------------------------------*/
/* Production Security group                                            */
/*----------------------------------------------------------------------*/

resource "aws_security_group" "yappa_prod" {
  name   = "yappa-prod-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow all when using this sg"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
  }

  ingress {
    description = "Allow public access to http"
    from_port   = 80
    to_port     = 80
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow hal9000 access to port"
    from_port   = 37533
    to_port     = 37533
    protocol    = 6
    cidr_blocks = ["3.218.131.120/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

/*----------------------------------------------------------------------*/
/* Staging Security group                                               */
/*----------------------------------------------------------------------*/

resource "aws_security_group" "yappa_stage" {
  name   = "yappa-stage-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow all when using this sg"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
  }

  ingress {
    description = "Allow public access to http"
    from_port   = 80
    to_port     = 80
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public access to Neo4j http connector"
    from_port   = 7474
    to_port     = 7474
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public access to Neo4j bolt connector"
    from_port   = 7687
    to_port     = 7687
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow hal9000 access"
    from_port   = 37533
    to_port     = 37533
    protocol    = 6
    cidr_blocks = ["3.218.131.120/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

/*----------------------------------------------------------------------*/
/* Development Security group                                           */
/*----------------------------------------------------------------------*/

resource "aws_security_group" "yappa_dev" {
  name   = "yappa-dev-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow all when using this sg"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
  }

  ingress {
    description = "Allow public access to http"
    from_port   = 80
    to_port     = 80
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public access to port (Fernando)"
    from_port   = 5000
    to_port     = 5000
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow hal9000 access to port"
    from_port   = 37533
    to_port     = 37533
    protocol    = 6
    cidr_blocks = ["3.218.131.120/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

/*----------------------------------------------------------------------*/
/* Load Balancers                                                       */
/*----------------------------------------------------------------------*/

resource "aws_lb" "yappa_gateway" {
  name               = "yappa-gateway"
  internal           = false
  load_balancer_type = "application"

  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]

  tags               = var.tags
}

resource "aws_lb_target_group" "yappa_gateway" {
  name                 = "yappa-gateway-tg"
  port                 = 5000
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener" "yappa_gateway_http" {
  load_balancer_arn  = "${aws_lb.yappa_gateway.arn}"
  port               = "80"
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_gateway.arn}"
  }
}

resource "aws_lb" "yappa_backend" {
  name               = "yappa-backend"
  internal           = true
  load_balancer_type = "application"

  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]

  tags = var.tags
}

resource "aws_lb_target_group" "yappa_comments" {
  name                 = "yappa-comments-tg"
  port                 = 3000
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener" "yappa_backend_http" {
  load_balancer_arn  = "${aws_lb.yappa_backend.arn}"
  port               = "80"
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_comments.arn}"
  }
}

/*----------------------------------------------------------------------*/
/* Admin (Public LB Microservice)                                       */
/*----------------------------------------------------------------------*/

resource "aws_lb_target_group" "yappa_admin" {
  name                 = "yappa-admin-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_gateway_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_admin.arn}"
  }

  condition {
    host_header {
      values = ["admin2.yappaapp.com"]
    }
  }
}

/*----------------------------------------------------------------------*/
/* Auth-App (Public LB Microservice)                                    */
/*----------------------------------------------------------------------*/

resource "aws_lb_target_group" "yappa_auth_app" {
  name                 = "yappa-auth-app-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_gateway_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_auth_app.arn}"
  }

  condition {
    host_header {
      values = ["auth-app.yappaapp.com"]
    }
  }
}

/*----------------------------------------------------------------------*/
/* Widget (Public LB Microservice)                                      */
/*----------------------------------------------------------------------*/

resource "aws_lb_target_group" "yappa_widget" {
  name                 = "yappa-widget-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_gateway_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_widget.arn}"
  }

  condition {
    host_header {
      values = ["widget.yappaapp.com"]
    }
  }
}

/*----------------------------------------------------------------------*/
/* Auth (Internal LB Microservice)                                      */
/*----------------------------------------------------------------------*/

// IMPORTANTE: CONFIRMAR CON CLIENTE SI ES POSIBLE ESTA RULE!!!

resource "aws_lb_target_group" "yappa_auth" {
  name                 = "yappa-auth-tg"
  port                 = 4000
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_backend_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_auth.arn}"
  }

  condition {
    host_header {
      values = ["auth.yappaapp.com"]
    }
  }
}

/*----------------------------------------------------------------------*/
/* Interactions (Internal LB Microservice)                              */
/*----------------------------------------------------------------------*/

resource "aws_lb_target_group" "yappa_interactions" {
  name                 = "yappa-interactions-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_backend_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_interactions.arn}"
  }

  condition {
    host_header {
      values = ["interactions.yappaapp.com"]
    }
  }
}

/*----------------------------------------------------------------------*/
/* Moderation (Internal LB Microservice)                                */
/*----------------------------------------------------------------------*/

// TARGET ACTUALMENTE VACIO (PUEDE SER UN SERVICIO FUTURO), CONSULTAR CLIENTE

resource "aws_lb_target_group" "yappa_moderation" {
  name                 = "yappa-moderation-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 60

  vpc_id               = "${aws_vpc.main.id}"

  tags                 = var.tags
}

resource "aws_lb_listener_rule" "host_based_routing" {
  listener_arn       = "${aws_lb_listener.yappa_backend_http.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.yappa_moderation.arn}"
  }

  condition {
    host_header {
      values = ["moderation.yappaapp.com"]
    }
  }
}
