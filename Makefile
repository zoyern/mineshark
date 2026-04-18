# ═══════════════════════════════════════════════════════════════════
#  MineShark — Makefile principal
# ═══════════════════════════════════════════════════════════════════
#  Tout passe par `make`. Aucune commande Docker / kubectl / git à
#  taper directement. Si tu cherches comment faire X, lance :
#      make help
#
#  Architecture : ce fichier inclut 3 sous-makefiles (make/*.mk) :
#    • k8s.mk    cycles K3s (production VPS)
#    • docker.mk cycles Docker Compose (dev local)
#    • admin.mk  utilitaires (ssh, backup, doctor, secrets)
#
#  Source des variables : .env (cf .env.example pour la liste complète)
# ═══════════════════════════════════════════════════════════════════

# Charge .env si présent ; sinon les valeurs par défaut des sous-makefiles
# s'appliquent. -include = pas d'erreur si manquant.
-include .env
export

# Cible par défaut (tapée quand on lance juste `make`)
.DEFAULT_GOAL := help

# Sous-makefiles — admin d'abord : définit les variables communes
# (RCON_SECRET_FILE, FWD_SECRET_FILE) et les cibles gen-secrets / init
# utilisées par k8s.mk et docker.mk.
include make/admin.mk
include make/k8s.mk
include make/docker.mk


# ─── help auto-généré (parse les commentaires ##) ──────────────────
# Convention : toute cible suivie de ` ## description` apparaît dans help.
help: ## Affiche cette aide
	@echo ""
	@echo "  MineShark — commandes disponibles"
	@echo "  ────────────────────────────────────"
	@awk 'BEGIN {FS = ":.*?## "} \
	     /^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' \
	     $(MAKEFILE_LIST) | sort
	@echo ""

.PHONY: help
