terraform {
  backend "s3" {}
}

provider "aws" {}

variable "NAME" {
  default = "nomoresecrets"
}

variable "DOMAIN" {
  default = "nomoresecrets.chivuku.la"
}

variable "AWS_ACCESS_KEY_ID" {}

variable "AWS_DEFAULT_REGION" {}

variable "AWS_SECRET_ACCESS_KEY" {}

resource "aws_vpc" "VPC" {
  cidr_block = "192.168.0.0/16"

  tags {
    Name = "${var.NAME}"
  }
}

data "aws_availability_zones" "AZS" {}

resource "aws_subnet" "PUBLIC_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index)}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_internet_gateway" "INTERNET" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route_table" "INTERNET_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_route" "PUBLIC_ROUTES" {
  route_table_id = "${aws_route_table.INTERNET_TABLE.id}"
  gateway_id = "${aws_internet_gateway.INTERNET.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "PUBLIC_TABLES" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PUBLIC_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.INTERNET_TABLE.id}"
}

resource "aws_eip" "IP" {
  vpc = true
}

resource "aws_nat_gateway" "NAT" {
  allocation_id = "${aws_eip.IP.id}"
  subnet_id = "${aws_subnet.PUBLIC_SUBNETS.0.id}"
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_subnet" "PRIVATE_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index + length(data.aws_availability_zones.AZS.names))}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route_table" "NAT_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route" "BRIDGE_ROUTE" {
  route_table_id  = "${aws_route_table.NAT_TABLE.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.NAT.id}"
}

resource "aws_route_table_association" "PRIVATE_ROUTES" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PRIVATE_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.NAT_TABLE.id}"
}

resource "aws_security_group" "SECURITY" {
  name = "${var.NAME}"
  vpc_id = "${aws_vpc.VPC.id}"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "CERTIFICATE" {
  domain_name = "${var.DOMAIN}"
  validation_method = "DNS"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_zone" "ZONE" {
  name = "${var.DOMAIN}."

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_record" "CERTIFICATE_RECORDS" {
  name = "${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_value}"]
  ttl = 60
  type = "${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.ZONE.zone_id}"
}

resource "aws_acm_certificate_validation" "VALIDATION" {
  certificate_arn = "${aws_acm_certificate.CERTIFICATE.arn}"
  validation_record_fqdns = ["${aws_route53_record.CERTIFICATE_RECORDS.*.fqdn}"]
}

resource "aws_lb" "LB" {
  name = "${var.NAME}"
  subnets = ["${aws_subnet.PUBLIC_SUBNETS.*.id}"]
  security_groups = ["${aws_security_group.SECURITY.id}"]
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_target_group" "TARGET" {
  name = "${var.NAME}"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.VPC.id}"
  target_type = "ip"
  
  health_check = {
    path = "/"
    matcher = "200-399"
  }
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_listener" "LISTENER" {
  load_balancer_arn = "${aws_lb.LB.id}"
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = "${aws_acm_certificate.CERTIFICATE.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.TARGET.id}"
    type = "forward"
  }
}

resource "aws_route53_record" "LISTENER_RECORD" {
  zone_id = "${aws_route53_zone.ZONE.zone_id}"
  name = "${var.DOMAIN}."
  type = "A"

  alias {
    name = "${aws_lb.LB.dns_name}"
    zone_id = "${aws_lb.LB.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_ecs_cluster" "CLUSTER" {
  name = "${var.NAME}"
}

resource "aws_cloudwatch_log_group" "LOG" {
  name = "${var.NAME}"

  tags = {
    name = "${var.NAME}"
  }
}

resource "aws_ecs_task_definition" "TASK" {
  container_definitions = <<DEFINITION
[
  {
    "name": "${var.NAME}",
    "image": "jhpyle/docassemble:latest",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "us-east-1",
        "awslogs-group": "${aws_cloudwatch_log_group.LOG.name}",
        "awslogs-stream-prefix": "main"
      }
    },
    "environment": [
      {
        "name": "REVISION",
        "value": "${timestamp()}"
      },
      {
        "name": "AWS_ACCESS_KEY_ID",
        "value": "${var.AWS_ACCESS_KEY_ID}"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "${var.AWS_DEFAULT_REGION}"
      },
      {
        "name": "AWS_SECRET_ACCESS_KEY",
        "value": "${var.AWS_SECRET_ACCESS_KEY}"
      }
    ]
  }
]
DEFINITION

  cpu = 256
  execution_role_arn = "${aws_iam_role.IAM.arn}"
  family = "${var.NAME}"
  memory = 512
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "SERVICE" {
  cluster = "${aws_ecs_cluster.CLUSTER.id}"
  desired_count = 1
  launch_type = "FARGATE"
  name = "${var.NAME}"
  task_definition = "${aws_ecs_task_definition.TASK.arn}"
  health_check_grace_period_seconds  = 600

  network_configuration {
    subnets = ["${aws_subnet.PRIVATE_SUBNETS.*.id}"]
    security_groups = ["${aws_security_group.SECURITY.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.TARGET.id}"
    container_name   = "${var.NAME}"
    container_port   = 80
  }
}
