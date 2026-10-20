# ======================= Öffentlich: Besucher -> Worker =======================

# Feste öffentliche IPs (eine pro Zone). Sie ändern sich nicht, solange der Load Balancer existiert.
resource "aws_eip" "web" {
  count  = 3
  domain = "vpc"
  tags   = { Name = "${var.projekt}-web-${count.index + 1}" }
}

resource "aws_lb" "web" {
  name                             = "${var.projekt}-web"
  load_balancer_type               = "network"
  internal                         = false
  security_groups                  = [aws_security_group.web_lb.id]
  enable_cross_zone_load_balancing = true # jede Zone verteilt auf ALLE Worker

  # "dynamic" erzeugt einen Block pro öffentlichem Subnetz
  dynamic "subnet_mapping" {
    for_each = aws_subnet.oeffentlich
    content {
      subnet_id     = subnet_mapping.value.id
      allocation_id = aws_eip.web[subnet_mapping.key].id
    }
  }
}

resource "aws_lb_target_group" "web" {
  for_each = local.web_ports

  name               = "${var.projekt}-${each.key}"
  port               = each.value
  protocol           = "TCP"
  vpc_id             = aws_vpc.main.id
  preserve_client_ip = "false"

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "web" {
  for_each = local.web_ports

  load_balancer_arn = aws_lb.web.arn
  port              = each.value
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web[each.key].arn
  }
}

resource "aws_lb_target_group_attachment" "web_http" {
  count            = var.worker_anzahl
  target_group_arn = aws_lb_target_group.web["http"].arn
  target_id        = aws_instance.worker[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_https" {
  count            = var.worker_anzahl
  target_group_arn = aws_lb_target_group.web["https"].arn
  target_id        = aws_instance.worker[count.index].id
  port             = 443
}

# ======================= Intern: Kubernetes-API -> Master =======================

resource "aws_lb" "api" {
  name                             = "${var.projekt}-api"
  load_balancer_type               = "network"
  internal                         = true # nur aus dem VPC erreichbar
  security_groups                  = [aws_security_group.api_lb.id]
  subnets                          = aws_subnet.privat[*].id
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "api" {
  name               = "${var.projekt}-api"
  port               = 6443
  protocol           = "TCP"
  vpc_id             = aws_vpc.main.id
  preserve_client_ip = "false"

  health_check {
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_target_group_attachment" "api" {
  count            = 3
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}
