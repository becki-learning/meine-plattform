data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.projekt}-admin"
  public_key = file(pathexpand("~/.ssh/kurs-server.pub"))
}

# Das gemeinsame Geheimnis, mit dem Knoten dem Cluster beitreten dürfen
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# ---------------- Bastion: der einzige Server mit öffentlicher IP ----------------
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_typ
  subnet_id              = aws_subnet.oeffentlich[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.admin.key_name

  tags = { Name = "${var.projekt}-bastion" }
}

# ---------------- 3 Master: einer pro Zone ----------------
resource "aws_instance" "master" {
  count = 3

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_typ
  subnet_id              = aws_subnet.privat[count.index].id # Zone a, b, c
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = aws_key_pair.admin.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.projekt}-master-${count.index + 1}", Rolle = "master" }

  # Ohne NAT kein Internet -> k3s-Installation würde scheitern
  depends_on = [aws_route_table_association.privat]
}

# ---------------- Worker: reihum auf die Zonen verteilt ----------------
resource "aws_instance" "worker" {
  count = var.worker_anzahl

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_typ
  subnet_id              = aws_subnet.privat[count.index % 3].id # % 3 = Rest bei Division -> 0,1,2,0,1,...
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = aws_key_pair.admin.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${var.projekt}-worker-${count.index + 1}", Rolle = "worker" }

  depends_on = [aws_route_table_association.privat]
}
