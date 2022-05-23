provider "aws" {
  profile = "default"
  region  = "eu-west-2"
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Private Subnets and routetables
data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    subnet_type = "private"
  }
}

data "aws_route_table" "private" {
  for_each  = data.aws_subnet_ids.private.ids
  subnet_id = each.value
}


# public Subnets and routetables
data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    subnet_type = "public"
  }
}

data "aws_route_table" "public" {
  for_each  = data.aws_subnet_ids.public.ids
  subnet_id = each.value
}



#create dns name
resource "aws_service_discovery_private_dns_namespace" "private_dns" {
  name        = "${var.name_prefix}-dns"
  description = "service discovery endpoint"
  vpc         = var.vpc_id
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-dns"
    }
  )
}

#attach dns name to ecsservice discovery
resource "aws_service_discovery_service" "service_discovery" {
  name = "${var.name_prefix}-discovery"
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-discovery"
    }
  )
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.private_dns.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    dns_records {
      ttl  = 10
      type = "SRV"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 3
  }
}

# create cluster
resource "aws_ecs_cluster" "sidecar" {
  name = "${var.name_prefix}-cluster"
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-cluster"
    }
  )
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}



#create ecs service and bind to cluster for manager
resource "aws_ecs_service" "sidecar" {
  name             = "${var.name_prefix}-service"
  cluster          = aws_ecs_cluster.sidecar.id
  task_definition  = aws_ecs_task_definition.fargate_task_definition.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  // Assuming we cannot have more than one instance at a time. Ever. 
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  network_configuration {
    subnets          = data.aws_subnet_ids.public.ids
    security_groups  = [aws_security_group.fargate_security_group.id]
    assign_public_ip = true
  }
  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery.arn
    # container_name = "${var.name_prefix}-controller"
    port = var.agent_port
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "${var.name_prefix}-manager"
    container_port   = var.controller_port
  }
  depends_on = [aws_lb_listener.https]
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-service"
    }
  )
}

resource "aws_cloudwatch_log_group" "jenkins_controller_log_group" {
  name              = var.name_prefix
  retention_in_days = 365
  # kms_key_id        = aws_kms_key.cloudwatch.arn
  # tags = var.default_tags
  tags = merge(
    var.default_tags,
    {
      Name = "Jenkins-container-logs"
    }
  )
}