
#######ECS assume role and execution role policy# # # 
data "aws_iam_policy_document" "ecs_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_execution_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "ecs_execution_role" {

  name               = "${var.name_prefix}-ecs_execution_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_policy.json
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-ecs_execution_role"
    }
  )
}

resource "aws_iam_policy" "ecs_execution_policy" {

  name   = "${var.name_prefix}-ecs-execution-policy"
  policy = data.aws_iam_policy_document.ecs_execution_policy.json
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-ecs-execution-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
}


# Jenkins Task Role and policy
data "aws_iam_policy_document" "jenkins_controller_task_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.jenkins_controller_log_group.arn}:*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientMount",
      "ecs:RegisterTaskDefinition",
      "ecs:ListClusters",
      "ecs:DescribeContainerInstances",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
    ]
    resources = [
      aws_efs_file_system.this.arn,
    ]
  }
}

resource "aws_iam_policy" "jenkins_controller_task_policy" {
  name   = "${var.name_prefix}-controller-task-policy"
  policy = data.aws_iam_policy_document.jenkins_controller_task_policy_doc.json
}

resource "aws_iam_role" "jenkins_controller_task_role" {
  name               = "${var.name_prefix}-controller-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_policy.json
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-controller-task-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "jenkins_controller_task" {
  role       = aws_iam_role.jenkins_controller_task_role.name
  policy_arn = aws_iam_policy.jenkins_controller_task_policy.arn
}



# iam user and password for jenkins controller plugin
resource "aws_iam_user" "jenkins_plugin_user" {
  name          = "${var.name_prefix}-user"
  force_destroy = true
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}-user"
    }
  )
}

data "aws_iam_policy_document" "jenkins_plugin_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:*",
      "autoscaling:*",
      "iam:ListInstanceProfiles",
      "iam:ListRoles",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "jenkins_plugin" {
  name   = "${var.name_prefix}-policy"
  user   = aws_iam_user.jenkins_plugin_user.name
  policy = data.aws_iam_policy_document.jenkins_plugin_policy_doc.json
}

# IAM for spot fleet instances to retrieve ecr repos
resource "aws_iam_instance_profile" "spotfleet_ec2_profile" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.spotfleet_ec2_role.name
}

data "aws_iam_policy_document" "ec2_spotfleet_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetAuthorizationToken",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject"
    ]
    resources = ["*"]

  }
  statement {
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:List*",
      "ecs:Describe*",
    ]
    resources = ["*"]
  }

}

resource "aws_iam_policy" "ec2_spotfleet_policy" {
  name   = "${var.name_prefix}-ec2-spotfleet-policy"
  policy = data.aws_iam_policy_document.ec2_spotfleet_policy_doc.json
}


resource "aws_iam_role" "spotfleet_ec2_role" {
  name = "${var.name_prefix}-instance-role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags = merge(
    var.default_tags,
    {
      Name = "${var.name_prefix}--instance-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "spotfleet_ec2_role_attach" {
  role       = aws_iam_role.spotfleet_ec2_role.name
  policy_arn = aws_iam_policy.ec2_spotfleet_policy.arn
}

// Backup
data "aws_iam_policy_document" "aws_backup_assume_policy" {
  count = var.efs_enable_backup ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "aws_backup_role" {
  count = var.efs_enable_backup ? 1 : 0

  name               = "${var.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.aws_backup_assume_policy[count.index].json
}

resource "aws_iam_role_policy_attachment" "backup_role_policy" {
  count = var.efs_enable_backup ? 1 : 0

  role       = aws_iam_role.aws_backup_role[count.index].id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
