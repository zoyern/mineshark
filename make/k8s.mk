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
	@# On exclut les configmap.yaml (placeholders) pour ne pas écraser le
	@# contenu poussé par sync-velocity-config / sync-paper-config.
	@# Les ConfigMaps réelles sont produites par les cibles sync-*.
	@find $(K8S_DIR)/velocity $(K8S_DIR)/main $(K8S_DIR)/mod \
	    -maxdepth 1 -name '*.yaml' -not -name 'configmap.yaml' \
	    -exec kubectl apply -f {} \;
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
	@# Quotes SIMPLES autour de la variable : les cles CurseForge ont le format
	@# bcrypt $$2a$$10$$... (dollar-signe suivi de chiffres). Avec quotes doubles
	@# le shell expanserait $$2, $$10, etc. comme parametres positionnels = vides
	@# = cle tronquee. Cote .env il faut aussi doubler chaque $$ pour que Make
	@# ne le mange pas lui-meme (voir commentaire CF_API_KEY dans .env.example).
	@kubectl create secret generic curseforge-api-key \
	    --namespace=$(NAMESPACE) \
	    --from-literal=api-key='$(CF_API_KEY)' \
	    --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic velocity-forwarding-secret \
	    --namespace=$(NAMESPACE) \
	    --from-literal=forwarding-secret="$$(cat $(FWD_SECRET_FILE))" \
	    --dry-run=client -o yaml | kubectl apply -f -
	@# ─── discord-chat-mod-config ───────────────────────────────────────
	@# Consommé par l'initContainer `discord-config-patch` du Deployment
	@# mc-mod (cf. k8s/mod/deployment.yaml). Si DISCORD_* sont vides dans
	@# .env, on crée quand même le Secret avec des chaînes vides : l'init
	@# container ne crash pas, le mod boot sans se connecter (log WARN).
	@# Ça permet `make mod-on` même sans bot Discord configuré.
	@kubectl create secret generic discord-chat-mod-config \
	    --namespace=$(NAMESPACE) \
	    --from-literal=token='$(DISCORD_TOKEN)' \
	    --from-literal=guild-id='$(DISCORD_GUILD_ID)' \
	    --from-literal=channel-id='$(DISCORD_CHANNEL_ID)' \
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
	    --from-file=bukkit.yml=config/bukkit.yml \
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

# Reset de la DATA mc-main (PVC) sans toucher au reste.
# Utile quand le monde est dans un état pourri et qu'on veut repartir
# d'un /data vide (Paper et Multiverse régénèrent tout au boot).
# Conservé : Velocity, ses PVC, les Secrets, les ConfigMaps.
reset-main-data: sync-paper-config ## Wipe complet du PVC mc-main (mondes + plugins data) et redéploie
	@echo "⚠️  Reset complet du PVC mc-main (toute la data Paper sera perdue) …"
	@# `kubectl scale` n'a pas `--ignore-not-found`. On tolère l'échec manuellement.
	@kubectl -n $(NAMESPACE) scale deployment mc-main --replicas=0 2>/dev/null || true
	@kubectl -n $(NAMESPACE) wait --for=delete pod -l app=mc-main --timeout=60s 2>/dev/null || true
	@kubectl -n $(NAMESPACE) delete pvc server-main-pvc --ignore-not-found
	@# Applique les manifests SAUF configmap.yaml (placeholder, écraserait
	@# la ConfigMap propre poussée par sync-paper-config).
	@find k8s/main -maxdepth 1 -name '*.yaml' -not -name 'configmap.yaml' \
	    -exec kubectl apply -f {} \;
	@echo "✓ PVC mc-main vierge + manifests à jour. Paper recrée tout (~30-60s)."
	@echo "   Suivre : make logs-main"

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


# ─── Bridge Discord (discord-chat-mod sur mc-mod) ──────────────────
# NB : les cibles `discord-setup` / `discord-status` / `discord-test`
# sont définies dans make/admin.mk car elles doivent tourner DEPUIS
# TA MACHINE LOCALE via SSH (kubectl n'est pas forcément installé en
# WSL). La seule chose ici dans k8s.mk, c'est la création du Secret
# vide par défaut dans `secrets` (voir plus haut), pour que `make up`
# sur le VPS ne crash pas si DISCORD_TOKEN est vide.
#
# Architecture globale :
#   .env (local)  ──[make discord-setup / make env-sync]──>  VPS
#         │                                                      │
#         │                                                      ▼
#         │                                          kubectl create secret
#         │                                          discord-chat-mod-config
#         ▼                                                      │
#   DISCORD_TOKEN / GUILD_ID / CHANNEL_ID                        │
#                                                                ▼
#                                          initContainer `discord-config-patch`
#                                          dans k8s/mod/deployment.yaml
#                                                                │
#                                                                ▼
#                                         /data/config/discord_chat_mod-common.toml
#
# Le Secret survit à `make mod-reset` (pas attaché au PVC).
# Universel : le mod est injecté via MODRINTH_PROJECTS, indépendant du
# modpack CurseForge.


.PHONY: up _apply secrets sync-velocity-config sync-paper-config down clean fclean re reset-main-data nuke \
        status logs-proxy logs-main logs-mod mod-on mod-off mod-reset \
        rcon-main rcon-mod
