locals {
  # Drei Availability Zones = drei getrennte Rechenzentren
  zonen = ["${var.region}a", "${var.region}b", "${var.region}c"]
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = var.projekt }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = var.projekt }
}

# ---------------- Öffentliche Subnetze: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24 ----------------
resource "aws_subnet" "oeffentlich" {
  count = 3

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1)
  availability_zone       = local.zonen[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.projekt}-oeffentlich-${local.zonen[count.index]}" }
}

resource "aws_route_table" "oeffentlich" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.projekt}-oeffentlich" }
}

resource "aws_route_table_association" "oeffentlich" {
  count          = 3
  subnet_id      = aws_subnet.oeffentlich[count.index].id
  route_table_id = aws_route_table.oeffentlich.id
}

# ---------------- NAT Gateway: privat -> Internet (nur ausgehend) ----------------
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.projekt}-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.oeffentlich[0].id # NAT selbst steht im ÖFFENTLICHEN Netz
  tags          = { Name = var.projekt }

  depends_on = [aws_internet_gateway.main]
}

# ---------------- Private Subnetze: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24 ----------------
resource "aws_subnet" "privat" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 11)
  availability_zone = local.zonen[count.index]

  tags = { Name = "${var.projekt}-privat-${local.zonen[count.index]}" }
}

resource "aws_route_table" "privat" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id # <- der Unterschied zu öffentlich!
  }

  tags = { Name = "${var.projekt}-privat" }
}

resource "aws_route_table_association" "privat" {
  count          = 3
  subnet_id      = aws_subnet.privat[count.index].id
  route_table_id = aws_route_table.privat.id
}
