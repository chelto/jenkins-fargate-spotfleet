data "aws_ssm_parameter" "linuxAmi" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}


# data "aws_ssm_parameter" "ssh_public-Key" {
#   name = var.sshkey
# }

resource "aws_autoscaling_group" "spotfleet_ASG" {
  name_prefix         = "${var.name_prefix}-asg"
  vpc_zone_identifier = data.aws_subnet_ids.public.ids
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.spotfleet_template.id
        version            = aws_launch_template.spotfleet_template.latest_version
      }
      override {
        instance_type     = "t3.medium"
        weighted_capacity = "5"
      }
      override {
        instance_type     = "t2.large"
        weighted_capacity = "4"
      }
      override {
        instance_type     = "t2.micro"
        weighted_capacity = "3"
      }
      override {
        instance_type     = "t3.micro"
        weighted_capacity = "2"
      }
      override {
        instance_type     = "t2.small"
        weighted_capacity = "1"
      }
    }
  }
  desired_capacity          = 0
  min_size                  = 0
  max_size                  = 10
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "spotfleet_template" {
  name_prefix            = "jenkinsspots"
  image_id               = var.spot_fleet_ami
  instance_type          = "t2.small"
  tags                   = var.default_tags
  key_name               = var.sshkey
  
  vpc_security_group_ids = [aws_security_group.ec2_autoscaling_group_sg.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.spotfleet_ec2_profile.arn
  }
}






