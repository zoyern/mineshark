#include build.mk
#include init.mk

.PHONY: all run logs logs-proxy logs-main down clean fclean re db migrate seed init

all:
	docker compose up --build -d
	@echo ""
	@echo "  Serveur Minecraft En Ligne!"
	@echo "  Connexion Java :    localhost:25565"
	@echo "  Connexion Bedrock : localhost:19132"
	@echo ""
	@echo "  Logs globaux :      make logs"
	@echo "  Logs du Proxy :     make logs-proxy"
	@echo "  Logs du Hub :       make logs-main"
	@echo "  Arrêter tout :      make down"
	@echo ""

run:
	docker compose up -d

# Voir les logs de tous les serveurs entremêlés
logs:
	docker compose logs -f

# Voir uniquement les logs du proxy (très utile pour débugger les connexions Bedrock/Java)
logs-proxy:
	docker compose logs -f ms-proxy

# Voir uniquement les logs du serveur principal (Paper)
logs-main:
	docker compose logs -f ms-main

# Arrête les serveurs proprement en sauvegardant les mondes
down:
	docker compose down

# --- SÉCURITÉ DES VOLUMES ---
# Le flag "-v" a été STRICTEMENT RETIRÉ ici pour ne jamais effacer tes mondes.
clean: down

# Supprime les conteneurs et les images téléchargées, MAIS GARDE LES DONNÉES INTACTES
fclean:
	docker compose down --rmi all

re: fclean all
ra: clean all
rr : clean run

# ==========================================
# Commandes Web / Backend (Prisma / Node.js)
# ==========================================
db:
	@echo "Prisma Studio: http://localhost:5555"
	docker compose run --rm -p 5555:5555 backend npx prisma studio --port 5555 --browser none

migrate:
	docker compose exec backend npx prisma migrate dev

seed:
	docker compose exec backend npx ts-node prisma/seed.ts