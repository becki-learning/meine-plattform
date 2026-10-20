resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0600" # enthält das k3s-Token

  content = <<-EOF
    # Automatisch von Terraform erzeugt – nicht von Hand bearbeiten!

    [bastion]
    ${aws_instance.bastion.public_ip}

    [master]
    %{for m in aws_instance.master~}
    ${m.private_ip}
    %{endfor~}

    [workers]
    %{for w in aws_instance.worker~}
    ${w.private_ip}
    %{endfor~}

    [k3s:children]
    master
    workers

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=~/.ssh/kurs-server
    api_endpoint=${aws_lb.api.dns_name}
    k3s_token=${random_password.k3s_token.result}
    spiel_host=${local.spiel_host}

    # Private Server sind nur über den Bastion erreichbar ("Jump Host")
    [k3s:vars]
    ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q -i ~/.ssh/kurs-server -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${aws_instance.bastion.public_ip}"'
  EOF
}
