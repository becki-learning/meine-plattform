# =====================================================================
#  Einstellungen
# =====================================================================
SHELL := /bin/bash
.DEFAULT_GOAL := help

export AWS_PROFILE      ?= kurs
export KUBECONFIG       := $(CURDIR)/kubeconfig
export TF_VAR_meine_ip  := $(shell curl -s -4 https://checkip.amazonaws.com)

TF       := terraform -chdir=terraform
TF_BOOT  := terraform -chdir=bootstrap
SSH_KEY  := $(HOME)/.ssh/kurs-server
REPO_URL := $(shell gh repo view --json url -q .url 2>/dev/null).git
EMAIL    := $(shell git config user.email)

.PHONY: help up bootstrap infra cluster gitops info tunnel tunnel-stop argocd grafana check down neue-sandbox

help: ## Diese Hilfe anzeigen
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# =====================================================================
#  Aufbauen
# =====================================================================
up: bootstrap infra cluster gitops info ## ALLES von null aufbauen

bootstrap: ## S3-Bucket für den Terraform-State anlegen
	$(TF_BOOT) init -input=false
	$(TF_BOOT) apply -auto-approve

infra: ## Netzwerk, Server und Load Balancer bauen
	$(TF) init -input=false -reconfigure -backend-config="bucket=$$($(TF_BOOT) output -raw bucket)"
	$(TF) apply -auto-approve

cluster: ## k3s mit Ansible installieren
	cd ansible && ansible-playbook k3s.yml

gitops: ## Argo CD installieren und an GitHub anschließen
	cd ansible && ansible-playbook gitops.yml -e repo_url=$(REPO_URL) -e letsencrypt_email=$(EMAIL)

info: ## Wichtige Adressen anzeigen
	@echo ""
	@echo "  Spiel:     $$($(TF) output -raw spiel_url)"
	@echo "  Bastion:   ssh -i $(SSH_KEY) ubuntu@$$($(TF) output -raw bastion_ip)"
	@echo "  Weiter:    make tunnel   dann   kubectl get nodes"
	@echo ""

# =====================================================================
#  Zugriff
# =====================================================================
tunnel: ## SSH-Tunnel zur Kubernetes-API öffnen (läuft im Hintergrund)
	@if lsof -i :6443 >/dev/null 2>&1; then echo "Tunnel läuft bereits"; else \
	  ssh -f -N -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	      -i $(SSH_KEY) -L 6443:$$($(TF) output -raw api_endpoint):6443 \
	      ubuntu@$$($(TF) output -raw bastion_ip) && echo "Tunnel offen: localhost:6443"; fi

tunnel-stop: ## SSH-Tunnel schließen
	@pkill -f "ssh -f -N .*-L 6443:" && echo "Tunnel geschlossen" || echo "Kein Tunnel offen"

argocd: tunnel ## Argo CD öffnen -> https://localhost:8080
	@echo "Benutzer: admin   Passwort: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	kubectl -n argocd port-forward svc/argocd-server 8080:443

grafana: tunnel ## Grafana öffnen -> http://localhost:3000
	@echo "Benutzer: admin   Passwort: $$(kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
	kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80

# =====================================================================
#  Prüfen & Abreißen
# =====================================================================
check: ## Code prüfen (wie die CI)
	terraform fmt -check -recursive
	$(TF_BOOT) init -backend=false -input=false >/dev/null && $(TF_BOOT) validate
	$(TF) init -backend=false -input=false >/dev/null && $(TF) validate
	cd ansible && ansible-playbook k3s.yml gitops.yml --syntax-check
	helm lint gitops/root gitops/spiel

down: tunnel-stop ## ALLES abreißen
	$(TF) destroy -auto-approve
	$(TF_BOOT) destroy -auto-approve
	rm -f kubeconfig ansible/inventory.ini

neue-sandbox: ## Lokale Reste einer alten Sandbox entfernen
	rm -f bootstrap/terraform.tfstate bootstrap/terraform.tfstate.backup kubeconfig ansible/inventory.ini
	@echo "Bereit für eine frische Sandbox -> make up"

