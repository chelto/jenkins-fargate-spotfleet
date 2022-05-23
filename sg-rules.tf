data "http" "github_metadata" {
  url = "https://api.github.com/meta"
}

locals {
  github_metadata    = jsondecode(data.http.github_metadata.body)
  github_webhook_ips = [for cidr in local.github_metadata.hooks[*] : cidr if can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/\\d{2}", cidr))]
}

# Jenkins fargate task SG
resource "aws_security_group" "fargate_security_group" {
  name        = "${var.name_prefix}-fargate-sg"
  description = "${var.name_prefix} security group"
  vpc_id      = var.vpc_id
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-fargate-sg"
    }
  )
}

# Jenkins only accessable from ALB sg
resource "aws_security_group_rule" "fargate_ALB_sg" {
  description              = "ristrict fargate to only ALB SG"
  type                     = "ingress"
  from_port                = var.controller_port
  to_port                  = var.controller_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fargate_security_group.id
  source_security_group_id = aws_security_group.ALB_sg.id
}

resource "aws_security_group_rule" "ecs_sg_egress_all_ports" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.fargate_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
}


# ALB SG, restricted to ip addresses.
resource "aws_security_group" "ALB_sg" {
  vpc_id = var.vpc_id
  name   = "${var.name_prefix}-ALB-sg"
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-ALB-sg"
    }
  )
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # cidr_blocks = var.alb_ingress_allow_cidrs
    cidr_blocks = concat(local.github_webhook_ips, var.alb_ingress_allow_cidrs)
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8089
    to_port     = 8089
    cidr_blocks = var.alb_ingress_allow_cidrs
  }

}

# EFS security group
resource "aws_security_group" "efs_security_group" {
  name        = "${var.name_prefix}-efs"
  description = "${var.name_prefix} efs security group"
  vpc_id      = var.vpc_id
  ingress {
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_security_group.id]
    from_port       = 2049
    to_port         = 2049
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-efs-sg"
    }
  )
}

# ec2 spots security group, needs ssh for jenkins plugin to init
resource "aws_security_group" "ec2_autoscaling_group_sg" {
  name        = "${var.name_prefix}-asg-sg"
  description = "${var.name_prefix} security group for ec2 instances launched by autoscaling group, allows fargate sg ingress"
  vpc_id      = var.vpc_id
  ingress {
    protocol        = "tcp"
    security_groups = [aws_security_group.fargate_security_group.id]
    from_port       = 22
    to_port         = 22
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-asg-sg"
    }
  )
}


