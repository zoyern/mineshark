# ═══════════════════════════════════════════════════════════════════
#  make/docker.mk — Cycle de vie Docker Compose (DEV local)
# ═══════════════════════════════════════════════════════════════════
#  Cibles préfixées `docker-` pour ne pas se confondre avec K8s.
# ═══════════════════════════════════════════════════════════════════

COMPOSE = docker compose


# ─── Démarrage initial (génère secret forwarding si absent) ────────
docker-up: _docker-prepare ## Lance la stack Docker en arrière-plan
	@$(COMPOSE) up --build -d
	@echo "✓ Stack en route. Logs : make docker-logs"

_docker-prepare:
	@test -f data/velocity/forwarding.secret \
	    || (mkdir -p data/velocity && openssl rand -hex 16 > data/velocity/forwarding.secret)


# ─── Arrêt ──────────────────────────────────────────────────────────
docker-down: ## Arrête la stack (garde les volumes)
	@$(COMPOSE) down

docker-clean: docker-down ## Alias de `docker-down`

docker-fclean: ## Stoppe la stack ET supprime les images locales
	@$(COMPOSE) down --rmi all

docker-re: docker-fclean docker-up ## Reset complet


# ─── Observabilité ──────────────────────────────────────────────────
docker-logs: ## Logs de tous les services (Ctrl+C pour quitter)
	@$(COMPOSE) logs -f

docker-status: ## État des conteneurs
	@$(COMPOSE) ps


# ─── Toggle serveur moddé (profil compose) ─────────────────────────
docker-mod-up: ## Démarre le serveur moddé en local
	@$(COMPOSE) --profile mod up -d mod-neoforge

docker-mod-down: ## Arrête le serveur moddé en local
	@$(COMPOSE) --profile mod stop mod-neoforge


# ─── Console RCON (Docker) ─────────────────────────────────────────
docker-rcon-main: ## Console RCON sur le serveur principal (Docker)
	@$(COMPOSE) exec main-paper rcon-cli

docker-rcon-mod: ## Console RCON sur le serveur moddé (Docker)
	@$(COMPOSE) exec mod-neoforge rcon-cli


.PHONY: docker-up _docker-prepare docker-down docker-clean docker-fclean \
        docker-re docker-logs docker-status docker-mod-up docker-mod-down \
        docker-rcon-main docker-rcon-mod
