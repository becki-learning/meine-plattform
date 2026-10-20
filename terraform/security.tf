locals {
  web_ports = { http = 80, https = 443 }
}

# ======================= Bastion: Admin-Zugang von außen =======================
resource "aws_security_group" "bastion" {
  name        = "${var.projekt}-bastion"
  description = "SSH-Sprungserver"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projekt}-bastion" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH nur von meiner IP"
  cidr_ipv4         = "${var.meine_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_raus" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ======================= Öffentlicher Load Balancer =======================
resource "aws_security_group" "web_lb" {
  name        = "${var.projekt}-web-lb"
  description = "Oeffentlicher Load Balancer"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projekt}-web-lb" }
}

# for_each erzeugt eine Regel pro Eintrag in local.web_ports -> http und https
resource "aws_vpc_security_group_ingress_rule" "web_lb_rein" {
  for_each = local.web_ports

  security_group_id = aws_security_group.web_lb.id
  description       = "${each.key} aus dem Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}

resource "aws_vpc_security_group_egress_rule" "web_lb_raus" {
  security_group_id = aws_security_group.web_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ======================= Interner Load Balancer (Kubernetes-API) =======================
resource "aws_security_group" "api_lb" {
  name        = "${var.projekt}-api-lb"
  description = "Interner Load Balancer fuer die Kubernetes-API"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projekt}-api-lb" }
}

resource "aws_vpc_security_group_ingress_rule" "api_lb_von_knoten" {
  security_group_id            = aws_security_group.api_lb.id
  description                  = "API von den Cluster-Knoten"
  referenced_security_group_id = aws_security_group.k3s.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_ingress_rule" "api_lb_von_bastion" {
  security_group_id            = aws_security_group.api_lb.id
  description                  = "API vom Bastion (kubectl-Tunnel)"
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_egress_rule" "api_lb_raus" {
  security_group_id = aws_security_group.api_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ======================= k3s-Knoten (Master + Worker) =======================
resource "aws_security_group" "k3s" {
  name        = "${var.projekt}-k3s"
  description = "k3s Master und Worker"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projekt}-k3s" }
}

resource "aws_vpc_security_group_ingress_rule" "k3s_intern" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "Knoten untereinander: etcd, API, Pod-Netz, kubelet"
  referenced_security_group_id = aws_security_group.k3s.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "k3s_ssh" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "SSH nur ueber den Bastion"
  referenced_security_group_id = aws_security_group.bastion.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "k3s_api" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "API ueber den internen Load Balancer"
  referenced_security_group_id = aws_security_group.api_lb.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_ingress_rule" "k3s_web" {
  for_each = local.web_ports

  security_group_id            = aws_security_group.k3s.id
  description                  = "${each.key} nur vom oeffentlichen Load Balancer"
  referenced_security_group_id = aws_security_group.web_lb.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "k3s_raus" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
