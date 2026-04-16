# ═══════════════════════════════════════════════════════
#  MineShark — Docker Compose (Dev local)
# ═══════════════════════════════════════════════════════

docker-up:
	@docker compose up --build -d
	@echo "✓ MineShark Docker lancé!"

docker-down:
	@docker compose down

docker-clean: docker-down

docker-fclean:
	@docker compose down --rmi all
	@echo "✓ Conteneurs supprimés. (VOLUMES INTACTS)"

docker-re: docker-fclean docker-up

docker-logs:
	docker compose logs -f

docker-logs-proxy:
	docker compose logs -f ms-proxy

docker-logs-main:
	docker compose logs -f ms-main

docker-logs-mod:
	docker compose logs -f ms-mod

docker-status:
	@docker compose ps
	@docker compose top 2>/dev/null | true

docker-mod-up:
	@docker compose --profile mod up -d mod-neoforge
	@echo "✓ Serveur moddé lancé (Docker)."

docker-mod-down:
	@docker compose --profile mod stop mod-neoforge