# ═══════════════════════════════════════════════════════════════════
#  make/k8s.mk — Cycle de vie K3s (production)
# ═══════════════════════════════════════════════════════════════════
#  Cibles "K3s" sans suffixe (up, down, re).
#  Cibles Docker équivalentes dans docker.mk avec préfixe `docker-`.
#  Pourquoi ? Le cas par défaut = production. Le dev local est l'exception.
# ═══════════════════════════════════════════════════════════════════

NAMESPACE ?= mineshark
K8S_DIR    = k8s


# ─── Déploiement complet ───────────────────────────────────────────
up: gen-secrets secrets sync-velocity-config sync-paper-config _apply ## Déploie tout sur K3s (proxy + main + mod en pause)

_apply:
	@echo "▶ Apply manifestes K8s …"
	@kubectl apply -f $(K8S_DIR)/base/
	@kubectl apply -f $(K8S_DIR)/velocity/
	@kubectl apply -f $(K8S_DIR)/main/
	@kubectl apply -f $(K8S_DIR)/mod/
	@echo "✓ MineShark déployé. Voir l'état : make status"


# ─── Création des secrets K8s à partir des fichiers locaux ─────────
# Les fichiers data/secrets/*.secret sont la source de vérité. Les
# Secrets K8s ne sont qu'un miroir (recréé à chaque `make secrets`).
secrets: gen-secrets ## (Re)crée les Secrets K8s depuis data/secrets/ et .env
	@echo "▶ Création/mise à jour des Secrets K8s …"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic rcon-secret \
	    --namespace=$(NAMESPACE) \
	    --from-literal=rcon-password="$$(cat $(RCON_SECRET_FILE))" \
	    --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic curseforge-api-key \
	    --namespace=$(NAMESPACE) \
	    --from-literal=api-key="$(CF_API_KEY)" \
	    --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic velocity-forwarding-secret \
	    --namespace=$(NAMESPACE) \
	    --from-literal=forwarding-secret="$$(cat $(FWD_SECRET_FILE))" \
	    --dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Secrets K8s prêts."


# ─── Synchronisation config/velocity.toml → ConfigMap K8s ──────────
sync-velocity-config: ## Pousse config/velocity.toml dans la ConfigMap K8s
	@echo "▶ Sync config/velocity.toml → ConfigMap velocity-config"
	@kubectl create configmap velocity-config \
	    --namespace=$(NAMESPACE) \
	    --from-file=velocity.toml=config/velocity.toml \
	    --dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ ConfigMap synchronisée. Redémarre Velocity : kubectl rollout restart deploy/velocity -n $(NAMESPACE)"


# ─── Synchronisation config/paper-*.yml + purpur.yml → ConfigMap ───
# Le Deployment mc-main monte `mineshark-paper-config` sur /config,
# itzg copie chaque fichier dans /data au 1er boot.
# À lancer après modif d'un config/*.yml, puis rollout restart.
sync-paper-config: ## Pousse config/paper-*.yml + purpur.yml dans la ConfigMap K8s
	@echo "▶ Sync config/*.yml → ConfigMap mineshark-paper-config"
	@kubectl create configmap mineshark-paper-config \
	    --namespace=$(NAMESPACE) \
	    --from-file=paper-global.yml=config/paper-global.yml \
	    --from-file=paper-world-defaults.yml=config/paper-world-defaults.yml \
	    --from-file=purpur.yml=config/purpur.yml \
	    --dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ ConfigMap synchronisée. Redémarre mc-main : kubectl rollout restart deploy/mc-main -n $(NAMESPACE)"


# ─── Arrêt / nettoyage ──────────────────────────────────────────────
down: ## Arrête les pods (garde PVC et Secrets)
	@kubectl -n $(NAMESPACE) delete deployment --all --ignore-not-found
	@kubectl -n $(NAMESPACE) delete svc --all --ignore-not-found

clean: down ## Alias de `down`

fclean: clean ## Reset complet (supprime aussi ConfigMap et Secrets — DATA conservée via PVC)
	@kubectl -n $(NAMESPACE) delete configmap --all --ignore-not-found
	@kubectl -n $(NAMESPACE) delete secret --all --ignore-not-found

re: fclean up ## Reset puis redéploie tout

# ⚠️ DESTRUCTIF : supprime aussi les volumes persistants (mondes !)
nuke: ## DANGER — supprime même les PVC (mondes effacés)
	@echo "⚠️  Suppression de TOUTES les données du namespace $(NAMESPACE)…"
	@kubectl -n $(NAMESPACE) delete deployment,svc,configmap,secret,pvc --all --ignore-not-found
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found


# ─── Observabilité ──────────────────────────────────────────────────
status: ## Affiche pods, services, volumes et IP externe du proxy
	@kubectl -n $(NAMESPACE) get pods,svc,pvc -o wide

logs-proxy: ## Logs Velocity (suit en live)
	@kubectl -n $(NAMESPACE) logs -f deployment/velocity -c velocity

logs-main: ## Logs serveur principal
	@kubectl -n $(NAMESPACE) logs -f deployment/mc-main -c minecraft

logs-mod: ## Logs serveur moddé
	@kubectl -n $(NAMESPACE) logs -f deployment/mc-mod -c minecraft


# ─── Toggle serveur moddé ──────────────────────────────────────────
mod-on: ## Démarre le serveur moddé
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=1
	@echo "✓ Mod démarrage en cours (3-5 min). Suivre : make logs-mod"

mod-off: ## Arrête le serveur moddé
	@kubectl -n $(NAMESPACE) scale deployment mc-mod --replicas=0

mod-reset: mod-off ## Supprime le PVC moddé (utile pour changer de modpack)
	@kubectl -n $(NAMESPACE) delete pvc server-mod-pvc --ignore-not-found
	@echo "✓ PVC moddé supprimé. \`make mod-on\` recréera tout."


# ─── Console RCON ──────────────────────────────────────────────────
rcon-main: ## Ouvre une console RCON sur le serveur principal
	@kubectl -n $(NAMESPACE) exec -it deployment/mc-main -c minecraft -- rcon-cli

rcon-mod: ## Ouvre une console RCON sur le serveur moddé
	@kubectl -n $(NAMESPACE) exec -it deployment/mc-mod -c minecraft -- rcon-cli


.PHONY: up _apply secrets sync-velocity-config sync-paper-config down clean fclean re nuke \
        status logs-proxy logs-main logs-mod mod-on mod-off mod-reset \
        rcon-main rcon-mod
