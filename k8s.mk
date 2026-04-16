# ═══════════════════════════════════════════════════════
#  MineShark — K3s (Orchestration Kubernetes)
# ═══════════════════════════════════════════════════════

NAMESPACE = mineshark
K8S_DIR = k8s

# Ajout des guillemets "$$(...)" pour empêcher l'erreur "got 9"
secrets:
	@test -f.env |

| (echo "❌.env manquant" && exit 1)
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic rcon-secret \
		--from-literal=rcon-password="$$(grep RCON_PASSWORD.env | cut -d= -f2-)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic curseforge-api-key \
		--from-literal=api-key="$$(grep CF_API_KEY.env | cut -d= -f2-)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(NAMESPACE) create secret generic velocity-forwarding-secret \
		--from-literal=forwarding-secret="$$(cat data/velocity/forwarding.secret 2>/dev/null |

| openssl rand -hex 16)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Secrets générés et injectés."

setup: secrets up

up: secrets
	@kubectl apply -f $(K8S_DIR)/base/
	@kubectl apply -f $(K8S_DIR)/velocity/
	@kubectl apply -f $(K8S_DIR)/main/
	@kubectl apply -f $(K8S_DIR)/mod/
	@echo "✓ MineShark déployé dans K3s!"

down:
	@kubectl -n $(NAMESPACE) delete deployment --all
	@kubectl -n $(NAMESPACE) delete svc --all
	@echo "✓ Pods et Services arrêtés. (TES VOLUMES SONT INTACTS)"

clean: down

fclean: clean
	@kubectl -n $(NAMESPACE) delete configmap --all
	@kubectl -n $(NAMESPACE) delete secret --all
	@echo "✓ Configuration et Secrets purgés. (TES VOLUMES SONT INTACTS)"

re: fclean up

status:
	@echo "=== Pods ==="
	@kubectl -n $(NAMESPACE) get pods -o wide
	@echo "\n=== Services ==="
	@kubectl -n $(NAMESPACE) get svc
	@echo "\n=== Disques (PVC) ==="
	@kubectl -n $(NAMESPACE) get pvc

logs:
	kubectl -n $(NAMESPACE) logs -f -l app=mineshark --all-containers --max-log-requests=10

logs-proxy:
	kubectl -n $(NAMESPACE) logs -f deployment/velocity -c velocity

logs-main:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-main -c minecraft

logs-mod:
	kubectl -n $(NAMESPACE) logs -f deployment/mc-mod -c minecraft

mod-on:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=1
	@echo "✓ Serveur moddé en cours d'allumage..."

mod-off:
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=0
	@echo "✓ Serveur moddé éteint."

restart-proxy:
	@kubectl -n $(NAMESPACE) rollout restart deployment/velocity

restart-main:
	@kubectl -n $(NAMESPACE) rollout restart deployment/mc-main