# ═══════════════════════════════════════════════════════════════════
#  make/admin.mk — Utilitaires d'administration
# ═══════════════════════════════════════════════════════════════════
#  Cibles transverses : SSH au VPS, backup, vérifications, déploiement
#  par git push, gestion des secrets auto-générés.
# ═══════════════════════════════════════════════════════════════════

# Valeurs par défaut si .env absent (le `?=` ne définit que si non set)
VPS_USER     ?= mineshark
VPS_IP       ?= 127.0.0.1
VPS_SSH_PORT ?= 22

# Emplacement des secrets auto-générés (jamais committés, gitignored via data/)
SECRETS_DIR        := data/secrets
RCON_SECRET_FILE   := $(SECRETS_DIR)/rcon.secret
FWD_SECRET_FILE    := data/velocity/forwarding.secret


# ─── SSH au VPS ────────────────────────────────────────────────────
ssh: ## Se connecte en SSH au VPS (cf. .env VPS_USER / VPS_IP / VPS_SSH_PORT)
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP)


# ─── Déploiement à distance ────────────────────────────────────────
deploy: ## Push git puis pull + make re sur le VPS
	@git push
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    'cd ~/mineshark && git pull && make re'


# ─── Migration ancien serveur 1.8 ──────────────────────────────────
OLD_BACKUP_ZIP ?= mc-server-old-backup.zip

old-server-reset: ## Réinstalle mc-server-old depuis $(OLD_BACKUP_ZIP) (état vierge)
	@test -f $(OLD_BACKUP_ZIP) \
	    || (echo "❌ $(OLD_BACKUP_ZIP) introuvable à la racine du repo."; exit 1)
	@command -v unzip >/dev/null 2>&1 \
	    || (echo "❌ unzip manquant : sudo apt install unzip -y"; exit 1)
	@if [ -d mc-server-old ]; then \
	    ts=$$(date +%Y%m%d-%H%M%S); \
	    echo "▶ mc-server-old existe déjà → archive de sécurité backups/old-server-pre-reset-$$ts.tar.gz"; \
	    mkdir -p backups; \
	    tar czf "backups/old-server-pre-reset-$$ts.tar.gz" mc-server-old; \
	    echo "▶ Suppression de mc-server-old/…"; \
	    rm -rf mc-server-old; \
	 fi
	@echo "▶ Décompression de $(OLD_BACKUP_ZIP)…"
	@# Détection du layout du zip : soit il contient `mc-server-old/...`
	@# à sa racine, soit les fichiers serveur directement. On sniffe la
	@# première entrée et on extrait dans le bon répertoire cible.
	@first=$$(unzip -Z1 $(OLD_BACKUP_ZIP) 2>/dev/null | head -1); \
	 if echo "$$first" | grep -qE "^mc-server-old/"; then \
	     echo "  ↳ layout : zip contient mc-server-old/ → extraction à la racine"; \
	     unzip -q $(OLD_BACKUP_ZIP) -d .; \
	 else \
	     echo "  ↳ layout : fichiers à la racine du zip → extraction dans mc-server-old/"; \
	     mkdir -p mc-server-old; \
	     unzip -q $(OLD_BACKUP_ZIP) -d mc-server-old; \
	 fi
	@test -d mc-server-old \
	    || (echo "❌ Extraction échouée, mc-server-old/ introuvable après unzip."; exit 1)
	@test -f mc-server-old/spigot-1.8.7.jar || test -f mc-server-old/server.properties \
	    || (echo "⚠️  Pas de spigot-1.8.7.jar ni server.properties détecté — structure inhabituelle, vérifie le contenu."; exit 1)
	@echo "✓ Reset OK. Prochaine étape : make old-server-prep"

old-server-prep: ## Prépare mc-server-old (cold backup + autoload=false + bungeecord=false)
	@./scripts/old-server-prep.sh

old-server-run: ## Lance mc-server-old avec log redirigé vers logs/migration.log
	@test -f mc-server-old/spigot-1.8.7.jar \
	    || (echo "❌ spigot-1.8.7.jar introuvable dans mc-server-old/"; exit 1)
	@test -x /usr/lib/jvm/java-8-openjdk-amd64/bin/java \
	    || (echo "❌ Java 8 absent. Installe : sudo apt install openjdk-8-jre -y"; exit 1)
	@mkdir -p mc-server-old/logs
	@cd mc-server-old && \
	    /usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx2G -jar spigot-1.8.7.jar nogui \
	    2>&1 | tee logs/migration.log


# ─── Backup manuel ─────────────────────────────────────────────────
backup: ## Snapshot manuel des données (data/main + data/velocity)
	@mkdir -p backups/manual
	@ts=$$(date +%Y%m%d-%H%M%S); \
	 tar czf backups/manual/mineshark-$$ts.tar.gz \
	     data/main data/velocity 2>/dev/null \
	     && echo "✓ backup créé : backups/manual/mineshark-$$ts.tar.gz"


# ─── Génération des secrets auto ───────────────────────────────────
# Principe : les secrets vivent dans data/ (gitignored), une seule
# génération par instance. Relancer ces cibles ne régénère PAS les
# secrets déjà présents — usage explicite : supprimer le fichier puis
# relancer (attention à synchroniser les backends après).
gen-secrets: ## Génère rcon.secret et forwarding.secret (s'ils manquent)
	@mkdir -p $(SECRETS_DIR) data/velocity
	@test -f $(RCON_SECRET_FILE) \
	    || (openssl rand -hex 16 > $(RCON_SECRET_FILE) \
	        && chmod 600 $(RCON_SECRET_FILE) \
	        && echo "  ✓ RCON secret généré      → $(RCON_SECRET_FILE)")
	@test -f $(FWD_SECRET_FILE) \
	    || (openssl rand -hex 16 > $(FWD_SECRET_FILE) \
	        && chmod 600 $(FWD_SECRET_FILE) \
	        && echo "  ✓ Forwarding secret généré → $(FWD_SECRET_FILE)")
	@test -f $(RCON_SECRET_FILE) && test -f $(FWD_SECRET_FILE) \
	    && echo "  ✓ Secrets OK."


show-secrets: ## Affiche les secrets générés (ne les copie PAS dans un buffer)
	@test -f $(RCON_SECRET_FILE) && echo "RCON_PASSWORD      = $$(cat $(RCON_SECRET_FILE))" \
	    || echo "⚠️  RCON secret absent (lance `make gen-secrets`)"
	@test -f $(FWD_SECRET_FILE)  && echo "FORWARDING_SECRET  = $$(cat $(FWD_SECRET_FILE))" \
	    || echo "⚠️  Forwarding secret absent"


# ─── Vérifications de santé ────────────────────────────────────────
doctor: ## Vérifie env, dépendances et cohérence config
	@echo "▶ Vérification environnement…"
	@command -v docker  >/dev/null 2>&1 && echo "  ✓ docker"   || echo "  ❌ docker manquant"
	@command -v kubectl >/dev/null 2>&1 && echo "  ✓ kubectl"  || echo "  ⚠️  kubectl manquant (OK si dev local seulement)"
	@command -v openssl >/dev/null 2>&1 && echo "  ✓ openssl"  || echo "  ❌ openssl manquant"
	@test -f .env                       && echo "  ✓ .env présent"      || echo "  ⚠️  .env absent — cp .env.example .env"
	@test -f $(RCON_SECRET_FILE)        && echo "  ✓ RCON secret"       || echo "  ⚠️  RCON secret absent — make gen-secrets"
	@test -f $(FWD_SECRET_FILE)         && echo "  ✓ Forwarding secret" || echo "  ⚠️  Forwarding secret absent — make gen-secrets"
	@grep -q "change-me" .env 2>/dev/null \
	    && echo "  ⚠️  des placeholders 'change-me' restent dans .env (CF_API_KEY ?)" \
	    || echo "  ✓ pas de placeholders évidents dans .env"
	@echo "▶ OK."


# ─── Init dossiers locaux + secrets initiaux ───────────────────────
# UID/GID des conteneurs itzg (non-root, voir docker-compose.yml `user:`).
# Les volumes montés doivent appartenir à ce couple pour que les
# conteneurs puissent écrire sans escalade de privilèges.
CONTAINER_UID ?= 1000
CONTAINER_GID ?= 1000

init: ## Crée les dossiers data/, backups/, .env initial et les secrets
	@mkdir -p data/velocity data/main data/mod data/secrets backups/main backups/manual
	@touch data/.gitkeep backups/.gitkeep
	@test -f .env || (cp .env.example .env && echo "✓ .env créé. Édite CF_API_KEY avant `make up`.")
	@$(MAKE) --no-print-directory gen-secrets
	@# Aligne les permissions sur l'UID non-root des conteneurs (silencieux
	@# si pas les droits — l'utilisateur est déjà propriétaire côté host).
	@chown -R $(CONTAINER_UID):$(CONTAINER_GID) data backups 2>/dev/null || true
	@echo ""
	@echo "▶ Init terminée. Prochaine étape :"
	@echo "    1. Édite .env si besoin (VPS_IP, CF_API_KEY)"
	@echo "    2. make doctor        # vérifie la cohérence"
	@echo "    3. make docker-up     # dev local  |  make up  # prod K3s"


# ─── Lint local (miroir de la CI GitHub Actions) ───────────────────
ci-lint: ## Reproduit la CI en local : yamllint + docker compose config + kubectl dry-run + shellcheck
	@echo "▶ yamllint…"
	@command -v yamllint >/dev/null 2>&1 \
	    || (echo "  ❌ yamllint manquant — pip install yamllint" && exit 1)
	@yamllint -d relaxed docker-compose.yml docker-compose.override.yml k8s/ .github/ config/
	@echo "▶ docker compose config…"
	@RCON_PASSWORD=ci-placeholder docker compose config -q
	@echo "▶ kubectl dry-run…"
	@for d in k8s/base k8s/velocity k8s/main k8s/mod; do \
	    echo "  $$d" && kubectl apply --dry-run=client -f "$$d/" >/dev/null || exit 1; \
	 done
	@echo "▶ shellcheck…"
	@command -v shellcheck >/dev/null 2>&1 \
	    && shellcheck -S warning scripts/*.sh \
	    || echo "  ⚠️  shellcheck absent (optionnel en local) — apt install shellcheck"
	@echo "▶ secrets…"
	@git ls-files --error-unmatch .env 2>/dev/null \
	    && (echo "  ❌ .env est tracké !" && exit 1) \
	    || echo "  ✓ .env non tracké"
	@echo "✓ Lint OK."


.PHONY: ssh deploy backup gen-secrets show-secrets doctor init ci-lint old-server-reset old-server-prep old-server-run
