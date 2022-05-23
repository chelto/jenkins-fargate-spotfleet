

resource "aws_ecs_task_definition" "fargate_task_definition" {
  family                   = "${var.name_prefix}-task_def"
  tags                     = var.default_tags
  task_role_arn            = var.jenkins_controller_task_role_arn != null ? var.jenkins_controller_task_role_arn : aws_iam_role.jenkins_controller_task_role.arn
  execution_role_arn       = var.ecs_execution_role_arn != null ? var.ecs_execution_role_arn : aws_iam_role.jenkins_controller_task_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.controller_cpu
  memory                   = var.controller_memory
  volume {
    name = "${var.name_prefix}-efs"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.this.id
        iam             = "ENABLED"
      }
    }
  }
  container_definitions = jsonencode([
    {
      memoryReservation = var.controller_memory
      name              = "${var.name_prefix}-manager"
      image             = var.image
      essential         = true
      portMappings = [
        {
          containerPort = var.controller_port,
          hostPort      = var.controller_port
        }
      ]
      mountPoints = [
        {
          containerPath = "/var/jenkins_home",
          sourceVolume  = "${var.name_prefix}-efs"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.jenkins_controller_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "controller"
        }
      }
      environment = [
        { name  = "JAVA_OPTS"
          value = "-Djenkins.install.runSetupWizard=true"
        }
      ]
    }
  ])
}

