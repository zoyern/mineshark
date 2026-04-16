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

	apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJkekNDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdGMyVnkKZG1WeUxXTmhRREUzTnpZek5qSTRNakV3SGhjTk1qWXdOREUyTVRjd056QXhXaGNOTXpZd05ERXpNVGN3TnpBeApXakFqTVNFd0h3WURWUVFEREJock0zTXRjMlZ5ZG1WeUxXTmhRREUzTnpZek5qSTRNakV3V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFUSUtTM05reVJBaU1hUm1qYXVWNG10SEZRdXdwYStCRnhGODRFR1R6VEgKU21MVDA3bUdtbFNvc0s4VjFLZjlCcWdzMDZ4S21OSmhWTEhmUEVQNUI4QzlvMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVThxWEx5SGVPOHJRSnZBSFJ2andJCmhrSG5mSkl3Q2dZSUtvWkl6ajBFQXdJRFNBQXdSUUloQU5RZEJmZnFaZDFjSTF2TlhTRy9weDBKRkRMZU9lYkQKMkZDV0xsVUpsbm9KQWlBdHI5MzA4TjNmdXlqMEl4dTNlV1pJd3pVaERpZlp1eHpUbGM1dktzYTZNdz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://127.0.0.1:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
users:
- name: default
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrakNDQVRlZ0F3SUJBZ0lJZmZSdjhtMERuVXd3Q2dZSUtvWkl6ajBFQXdJd0l6RWhNQjhHQTFVRUF3d1kKYXpOekxXTnNhV1Z1ZEMxallVQXhOemMyTXpZeU9ESXhNQjRYRFRJMk1EUXhOakUzTURjd01Wb1hEVEkzTURReApOakUzTURjd01Wb3dNREVYTUJVR0ExVUVDaE1PYzNsemRHVnRPbTFoYzNSbGNuTXhGVEFUQmdOVkJBTVRESE41CmMzUmxiVHBoWkcxcGJqQlpNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQTBJQUJMb0VNSlR0UmlBUVV5UTIKQUhTcUxFOVRBeDQ5c0VnYkxTMlRDdTZNWEpuRTJxa2d0VTFCVUEvRFV0eE1kQkZuQ2hVMTRpdGlIZnhnRHJDRQpMQ1A1UUQyalNEQkdNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUtCZ2dyQmdFRkJRY0RBakFmCkJnTlZIU01FR0RBV2dCVERuQThnVGorTUE2NHRvVjZtYVBERU5RQjhPREFLQmdncWhrak9QUVFEQWdOSkFEQkcKQWlFQTFGTmVlb0ZqalFxczU4aW4xUGF2TFRQN1o1azgvOXRXaFFIWnFOMEdwTVlDSVFDaGZhaFpCM2lhNmxiWQp1V3RHM3ZlcVlxTUVUT0dyZEUraGJHR0I0WDBSVHc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLQpNSUlCZHpDQ0FSMmdBd0lCQWdJQkFEQUtCZ2dxaGtqT1BRUURBakFqTVNFd0h3WURWUVFEREJock0zTXRZMnhwClpXNTBMV05oUURFM056WXpOakk0TWpFd0hoY05Nall3TkRFMk1UY3dOekF4V2hjTk16WXdOREV6TVRjd056QXgKV2pBak1TRXdId1lEVlFRRERCaHJNM010WTJ4cFpXNTBMV05oUURFM056WXpOakk0TWpFd1dUQVRCZ2NxaGtqTwpQUUlCQmdncWhrak9QUU1CQndOQ0FBUkhMQlVLKzNQMnI5VmljMWsyYlBlUmpvSmhmS0Y3c1RFaVVWTk9BUjd3ClZ1MHljR0lTOEo1MGxNUlVZaTdPdjl0QjVRaG9FenVrVnlmN3BIUUtESXNHbzBJd1FEQU9CZ05WSFE4QkFmOEUKQkFNQ0FxUXdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVV3NXdQSUU0L2pBT3VMYUZlcG1qdwp4RFVBZkRnd0NnWUlLb1pJemowRUF3SURTQUF3UlFJaEFLdldsc2hHa3orbVRqc0VybGQ4U1F3TWMzamgvZldoCnFmWmhXNjlnL2ZmQkFpQkxXNlBUbEt1VDEvSGJuVWlmYlowd3NmRnpZaDUzYnQyZW5yd1Fob0N5Z2c9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSUU5VHN2VXFvNllQT1FTS3hHQ3lsSkttUTlYQTlzelRzOHJ5bHRCU1F6dXRvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFdWdRd2xPMUdJQkJUSkRZQWRLb3NUMU1ESGoyd1NCc3RMWk1LN294Y21jVGFxU0MxVFVGUQpEOE5TM0V4MEVXY0tGVFhpSzJJZC9HQU9zSVFzSS9sQVBRPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=