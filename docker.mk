# ═══════════════════════════════════════════════════════
#  MineShark — Docker Compose (dev local)
#  Inclus dans le Makefile principal : include docker.mk
# ═══════════════════════════════════════════════════════

.PHONY: docker-up docker-down docker-logs docker-logs-proxy docker-logs-main \
        docker-status docker-clean docker-re docker-mod-up docker-mod-down

# ── Lancement / Arrêt ────────────────────────────────

docker-up:
	@docker compose up --build -d
	@echo ""
	@echo "  ✓ MineShark Docker lancé !"
	@echo "    Java :    localhost:25565"
	@echo "    Bedrock : localhost:19132"
	@echo ""

docker-down:
	@docker compose down

docker-re: docker-clean docker-up

# ── Logs ─────────────────────────────────────────────

docker-logs:
	docker compose logs -f

docker-logs-proxy:
	docker compose logs -f proxy-velocity

docker-logs-main:
	docker compose logs -f main-paper

docker-logs-mod:
	docker compose logs -f mod-neoforge

# ── Status ───────────────────────────────────────────

docker-status:
	@docker compose ps
	@echo ""
	@docker compose top 2>/dev/null || true

# ── Serveur moddé (profile séparé) ──────────────────

docker-mod-up:
	@docker compose --profile mod up -d mod-neoforge
	@echo "✓ Serveur moddé lancé (3-5 min de démarrage)"

docker-mod-down:
	@docker compose --profile mod stop mod-neoforge
	@echo "✓ Serveur moddé éteint"

# ── Nettoyage (sans -v = mondes protégés) ────────────

docker-clean:
	@docker compose --profile mod down --rmi all
