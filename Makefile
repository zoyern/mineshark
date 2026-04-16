# ═══════════════════════════════════════════════════════
#  MineShark — Makefile principal
#  K3s = commandes par défaut (make up, make status, ...)
#  Docker = préfixées (make docker-up, make docker-logs, ...)
# ═══════════════════════════════════════════════════════

include k8s.mk
include docker.mk

HOSTNAME = mineshark
IP = 159.195.146.234

# ── Commande par défaut ──────────────────────────────

.DEFAULT_GOAL = help

help:
	@echo ""
	@echo "  ╔═══════════════════════════════════════════╗"
	@echo "  ║         §b MineShark §r— Commandes          ║"
	@echo "  ╚═══════════════════════════════════════════╝"
	@echo ""
	@echo "  K3s (défaut) :"
	@echo "    make setup          Cluster k3d + secrets + deploy"
	@echo "    make up             Déploie les manifests"
	@echo "    make down           Supprime le namespace"
	@echo "    make status         Pods, services, PVC, nodes"
	@echo "    make logs           Tous les logs"
	@echo "    make logs-proxy     Logs Velocity"
	@echo "    make logs-main      Logs Paper"
	@echo "    make logs-mod       Logs NeoForge moddé"
	@echo "    make mod-on         Allumer le moddé"
	@echo "    make mod-off        Éteindre le moddé"
	@echo "    make restart-proxy  Redémarrer Velocity"
	@echo "    make restart-main   Redémarrer Paper"
	@echo "    make clean          Supprimer le cluster k3d"
	@echo "    make re             Tout recréer from scratch"
	@echo ""
	@echo "  Docker Compose :"
	@echo "    make docker-up      Lancer les conteneurs"
	@echo "    make docker-down    Arrêter les conteneurs"
	@echo "    make docker-status  État des conteneurs"
	@echo "    make docker-logs    Logs en temps réel"
	@echo "    make docker-mod-up  Lancer le serveur moddé"
	@echo "    make docker-mod-down  Éteindre le moddé"
	@echo "    make docker-clean   Supprimer conteneurs + images"
	@echo "    make docker-re      clean + up"
	@echo ""

ssh:
	ssh -p 2222 $(HOSTNAME)@$(IP)

	