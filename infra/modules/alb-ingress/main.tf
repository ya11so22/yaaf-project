# The entry point in front of the cluster's ingress controller (ADR-0016): an internet-facing ALB whose
# target group sends HTTP to the controller's NodePort on the cluster node.
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_ids

  # The ingress controller routes by Host header. Without this the ALB replaces it with the target's
  # host and port, and every request would land on the controller's default backend.
  preserve_host_header = true

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = var.name
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = var.target_port
  target_type = "ip"

  health_check {
    path = "/"
    # Traefik answers 404 for a host it has no rule for, which still means it is alive.
    matcher = "200-404"
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "node" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_host
  port             = var.target_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = var.tags
}
