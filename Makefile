# ═══════════════════════════════════════════════════════
#  MineShark — Makefile Principal (Norme 42)
# ═══════════════════════════════════════════════════════

USER = mineshark
IP = 159.195.146.234
SSH_PORT = 2222

include k8s.mk
include docker.mk

.DEFAULT_GOAL = help

help:
	@echo "\n  ╔═══════════════════════════════════════════╗"
	@echo "  ║         MineShark — Commandes             ║"
	@echo "  ╚═══════════════════════════════════════════╝\n"
	@echo "  K3s (Serveur Prod Netcup) :"
	@echo "    make setup          Secrets + Deploy K3s"
	@echo "    make up             Déploie les manifests"
	@echo "    make down           Arrête les pods (Garde les volumes)"
	@echo "    make status         État du cluster"
	@echo "    make logs           Tous les logs"
	@echo "    make logs-proxy     Logs Velocity"
	@echo "    make logs-main      Logs Paper"
	@echo "    make logs-mod       Logs NeoForge"
	@echo "    make clean          Alias de down"
	@echo "    make fclean         Down + supprime Configs/Secrets (VOLUMES SAUVÉS)"
	@echo "    make re             fclean + up\n"
	@echo "  Accès Serveur :"
	@echo "    make ssh            Connexion SSH au VPS\n"

ssh:
	ssh -p $(SSH_PORT) $(USER)@$(IP)