# ═══════════════════════════════════════════════════════════════════
#  make/admin.mk — Utilitaires d'administration
# ═══════════════════════════════════════════════════════════════════
#  Cibles transverses : SSH au VPS, backup, vérifications, déploiement
#  par git push, etc.
# ═══════════════════════════════════════════════════════════════════

# Valeurs par défaut si .env absent (le `?=` ne définit que si non set)
VPS_USER     ?= mineshark
VPS_IP       ?= 127.0.0.1
VPS_SSH_PORT ?= 22


# ─── SSH au VPS ────────────────────────────────────────────────────
ssh: ## Se connecte en SSH au VPS (cf. .env VPS_USER / VPS_IP / VPS_SSH_PORT)
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP)


# ─── Déploiement à distance ────────────────────────────────────────
deploy: ## Push git puis pull + make re sur le VPS
	@git push
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    'cd ~/mineshark && git pull && make re'


# ─── Backup manuel ─────────────────────────────────────────────────
backup: ## Snapshot manuel des données (data/main + data/velocity)
	@mkdir -p backups/manual
	@ts=$$(date +%Y%m%d-%H%M%S); \
	 tar czf backups/manual/mineshark-$$ts.tar.gz \
	     data/main data/velocity 2>/dev/null \
	     && echo "✓ backup créé : backups/manual/mineshark-$$ts.tar.gz"


# ─── Vérifications de santé ────────────────────────────────────────
doctor: ## Vérifie env, dépendances et cohérence config
	@echo "▶ Vérification environnement…"
	@command -v docker >/dev/null 2>&1   && echo "  ✓ docker"   || echo "  ❌ docker manquant"
	@command -v kubectl >/dev/null 2>&1  && echo "  ✓ kubectl"  || echo "  ❌ kubectl manquant (OK si dev local seulement)"
	@command -v openssl >/dev/null 2>&1  && echo "  ✓ openssl"  || echo "  ❌ openssl manquant"
	@test -f .env                        && echo "  ✓ .env présent" || echo "  ⚠️  .env absent — `cp .env.example .env`"
	@grep -q "change-me" .env 2>/dev/null \
	    && echo "  ⚠️  des secrets sont à 'change-me' dans .env" \
	    || echo "  ✓ pas de placeholders évidents dans .env"
	@echo "▶ OK."


# ─── Init dossiers locaux ──────────────────────────────────────────
init: ## Crée les dossiers data/ backups/ et .env initial
	@mkdir -p data/velocity data/main data/mod backups/main
	@touch data/.gitkeep backups/.gitkeep
	@test -f .env || (cp .env.example .env && echo "✓ .env créé. Édite-le avant `make up`.")


.PHONY: ssh deploy backup doctor init
