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

data "aws_vpc" "VPC" {
  tags = {
    Name = "aol"
  }
}

data "aws_subnet_ids" "PUBLIC_SUBNETS" {
  vpc_id = "${data.aws_vpc.VPC.id}"
  tags = {
    Name = "aol"
    Type = "Public"
  }
}

data "aws_subnet_ids" "PRIVATE_SUBNETS" {
  vpc_id = "${data.aws_vpc.VPC.id}"
  tags = {
    Name = "aol"
    Type = "Private"
  }
}

resource "aws_security_group" "SECURITY" {
  name = "${var.NAME}"
  vpc_id = "${data.aws_vpc.VPC.id}"

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

  tags = {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_zone" "ZONE" {
  name = "${var.DOMAIN}."

  tags = {
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
  validation_record_fqdns = aws_route53_record.CERTIFICATE_RECORDS.*.fqdn
}

resource "aws_iam_role" "IAM" {
  name = "${var.NAME}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "POLICY" {
  name = "${var.NAME}"
  role = "${aws_iam_role.IAM.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_lb" "LB" {
  name = "${var.NAME}"
  subnets = data.aws_subnet_ids.PUBLIC_SUBNETS.ids
  security_groups = ["${aws_security_group.SECURITY.id}"]
  
  tags = {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_target_group" "TARGET" {
  name = "${var.NAME}"
  port = 8200
  protocol = "HTTP"
  vpc_id = "${data.aws_vpc.VPC.id}"
  target_type = "ip"
  
  health_check {
    path = "/"
    matcher = "200-399"
  }
  
  tags = {
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
    "image": "617580300246.dkr.ecr.us-east-1.amazonaws.com/nomoresecrets:master",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 8200,
        "hostPort": 8200
      },
      {
        "containerPort": 8201,
        "hostPort": 8201
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
    subnets = data.aws_subnet_ids.PRIVATE_SUBNETS.ids
    security_groups = ["${aws_security_group.SECURITY.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.TARGET.id}"
    container_name   = "${var.NAME}"
    container_port   = 8200
  }
}
