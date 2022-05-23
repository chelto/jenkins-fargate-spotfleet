resource "aws_lb" "this" {
  name               = replace("${var.name_prefix}-crtl-alb", "_", "-")
  internal           = var.alb_type_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB_sg.id]
  subnets            = data.aws_subnet_ids.public.ids

  dynamic "access_logs" {
    for_each = var.alb_enable_access_logs ? [true] : []
    content {
      bucket  = var.alb_access_logs_bucket_name
      prefix  = var.alb_access_logs_s3_prefix
      enabled = true
    }
  }

  tags = merge(
    var.default_tags,
    {
      Name = replace("${var.name_prefix}-crtl-alb", "_", "-")
  })
}

resource "aws_lb_target_group" "this" {
  name        = replace("${var.name_prefix}-crtl", "_", "-")
  port        = var.controller_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    enabled = true
    path    = "/login"
  }
  tags       = var.default_tags
  depends_on = [aws_lb.this]

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  certificate_arn   = var.alb_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = aws_lb_listener.http.arn

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    http_header {
      http_header_name = "*"
      values           = ["*"]
    }
  }
}