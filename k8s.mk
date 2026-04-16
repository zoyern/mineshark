# ═══════════════════════════════════════════════════════
#  MineShark — K3s / k3d (orchestration Kubernetes)
#  Inclus dans le Makefile principal : include k8s.mk
# ═══════════════════════════════════════════════════════

CLUSTER   ?= mineshark
NAMESPACE ?= mineshark
K8S_DIR   := k8s

.PHONY: setup secrets up down status logs logs-proxy logs-main logs-mod \
        mod-on mod-off restart-proxy restart-main clean re \
        k3d-create k3d-stop k3d-start k3d-delete

# ══════════════════════════════════════════════════════
#  Cluster k3d (local uniquement)
# ══════════════════════════════════════════════════════

k3d-create:
	@echo "⏳ Création du cluster k3d '$(CLUSTER)'..."
	@k3d cluster list 2>/dev/null | grep -q $(CLUSTER) \
		&& echo "✓ Cluster '$(CLUSTER)' existe déjà" \
		|| k3d cluster create $(CLUSTER) \
			--port "25565:30565@loadbalancer" \
			--port "19132:30132/udp@loadbalancer" \
			--k3s-arg "--disable=traefik@server:0"
	@echo "✓ Cluster prêt"

k3d-stop:
	@k3d cluster stop $(CLUSTER)
	@echo "✓ Cluster arrêté (données préservées)"

k3d-start:
	@k3d cluster start $(CLUSTER)
	@echo "✓ Cluster redémarré"

k3d-delete:
	@k3d cluster delete $(CLUSTER) 2>/dev/null || true
	@echo "✓ Cluster supprimé"

# ══════════════════════════════════════════════════════
#  Secrets
# ══════════════════════════════════════════════════════

secrets:
	@test -f .env || (echo "❌ .env manquant — copie .env.example" && exit 1)
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic rcon-secret \
		--from-literal=rcon-password=$$(grep RCON_PASSWORD .env | cut -d= -f2) \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic curseforge-api-key \
		--from-literal=api-key=$$(grep CF_API_KEY .env | cut -d= -f2) \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic velocity-forwarding-secret \
		--from-literal=forwarding-secret=$$(cat data/velocity/forwarding.secret 2>/dev/null || echo "CHANGE_ME") \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Secrets OK"

# ══════════════════════════════════════════════════════
#  Deploy / Teardown
# ══════════════════════════════════════════════════════

# setup = créer cluster k3d + secrets + deploy (one-shot)
setup: k3d-create secrets up

# up = applique les manifests (idempotent)
up: secrets
	@kubectl apply -f $(K8S_DIR)/base/
	@kubectl apply -f $(K8S_DIR)/velocity/
	@kubectl apply -f $(K8S_DIR)/main/
	@kubectl apply -f $(K8S_DIR)/mod/
	@echo ""
	@echo "  ✓ MineShark déployé dans K3s !"
	@echo "    make status     voir l'état"
	@echo "    make mod-on     allumer le moddé"
	@echo ""

down:
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "✓ Namespace $(NAMESPACE) supprimé"

# clean = supprime cluster k3d entier
clean: k3d-delete

# re = from scratch
re: clean setup

# ══════════════════════════════════════════════════════
#  Monitoring
# ══════════════════════════════════════════════════════

status:
	@echo "=== Pods ==="
	@kubectl -n $(NAMESPACE) get pods -o wide 2>/dev/null || echo "Aucun pod"
	@echo ""
	@echo "=== Services ==="
	@kubectl -n $(NAMESPACE) get svc 2>/dev/null || echo "Aucun service"
	@echo ""
	@echo "=== PVC ==="
	@kubectl -n $(NAMESPACE) get pvc 2>/dev/null || echo "Aucun PVC"
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide 2>/dev/null || echo "Pas de nodes"

logs:
	kubectl -n $(NAMESPACE) logs -f --all-containers --max-log-requests=10 --prefix -l component

logs-proxy:
	kubectl -n $(NAMESPACE) logs -f deployment/velocity -c velocity

logs-main:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-main -c minecraft

logs-mod:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-mod -c minecraft

# ══════════════════════════════════════════════════════
#  Serveur moddé (on/off)
# ══════════════════════════════════════════════════════

mod-on:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=1
	@echo "✓ Serveur moddé lancé (3-5 min de démarrage)"

mod-off:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=0
	@echo "✓ Serveur moddé éteint"

# ══════════════════════════════════════════════════════
#  Restart rapide (sans recréer le PVC)
# ══════════════════════════════════════════════════════

restart-proxy:
	@kubectl -n $(NAMESPACE) rollout restart deployment/velocity
	@echo "✓ Velocity redémarré"

restart-main:
	@kubectl -n $(NAMESPACE) rollout restart deployment/mc-main
	@echo "✓ Paper Main redémarré"
