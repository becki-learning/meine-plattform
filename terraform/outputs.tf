locals {
  # sslip.io: kostenloser DNS-Dienst. "spiel.1-2-3-4.sslip.io" zeigt auf die IP 1.2.3.4.
  # Damit bekommen wir ohne eigene Domain einen echten Hostnamen -> nötig für HTTPS.
  spiel_host = "spiel.${replace(aws_eip.web[0].public_ip, ".", "-")}.sslip.io"
}

output "spiel_url" {
  value = "https://${local.spiel_host}"
}

output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "api_endpoint" {
  description = "Interne Adresse der Kubernetes-API (nur über den Bastion erreichbar)"
  value       = aws_lb.api.dns_name
}

output "master_ips" {
  value = aws_instance.master[*].private_ip
}

output "worker_ips" {
  value = aws_instance.worker[*].private_ip
}
