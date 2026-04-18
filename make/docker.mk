# ═══════════════════════════════════════════════════════════════════
#  make/docker.mk — Cycle de vie Docker Compose (DEV local)
# ═══════════════════════════════════════════════════════════════════
#  Cibles préfixées `docker-` pour ne pas se confondre avec K8s.
#
#  Secrets : RCON_PASSWORD est lu depuis data/secrets/rcon.secret et
#  exporté à la volée pour `docker compose`. Il n'apparaît JAMAIS
#  dans .env ni dans le fichier compose (traçabilité zéro fuite).
# ═══════════════════════════════════════════════════════════════════

COMPOSE = docker compose

# Macro qui prépare l'environnement compose (secret lu à la volée)
# et appelle `docker compose` avec l'action passée en argument.
# Usage : $(call compose_run,up --build -d)
define compose_run
	@RCON_PASSWORD=$$(cat $(RCON_SECRET_FILE)) $(COMPOSE) $(1)
endef


# ─── Démarrage initial (s'assure que les secrets existent) ─────────
docker-up: gen-secrets ## Lance la stack Docker en arrière-plan
	$(call compose_run,up --build -d)
	@echo "✓ Stack en route. Logs : make docker-logs"


# ─── Arrêt ──────────────────────────────────────────────────────────
docker-down: ## Arrête la stack (garde les volumes)
	$(call compose_run,down)

docker-clean: docker-down ## Alias de `docker-down`

docker-fclean: ## Stoppe la stack ET supprime les images locales
	$(call compose_run,down --rmi all)

docker-re: docker-fclean docker-up ## Reset complet


# ─── Observabilité ──────────────────────────────────────────────────
docker-logs: ## Logs de tous les services (Ctrl+C pour quitter)
	$(call compose_run,logs -f)

docker-status: ## État des conteneurs
	$(call compose_run,ps)


# ─── Toggle serveur moddé (profil compose) ─────────────────────────
docker-mod-up: gen-secrets ## Démarre le serveur moddé en local
	$(call compose_run,--profile mod up -d mod-neoforge)

docker-mod-down: ## Arrête le serveur moddé en local
	$(call compose_run,--profile mod stop mod-neoforge)


# ─── Console RCON (Docker) ─────────────────────────────────────────
docker-rcon-main: ## Console RCON sur le serveur principal (Docker)
	$(call compose_run,exec main-paper rcon-cli)

docker-rcon-mod: ## Console RCON sur le serveur moddé (Docker)
	$(call compose_run,exec mod-neoforge rcon-cli)


.PHONY: docker-up docker-down docker-clean docker-fclean \
        docker-re docker-logs docker-status docker-mod-up docker-mod-down \
        docker-rcon-main docker-rcon-mod
