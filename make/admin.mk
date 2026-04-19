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


# ─── Console RCON (envoyer des commandes MC au serveur main) ──────
# En k3s, on exec rcon-cli dans le pod mc-main. RCON est activé via
# ENABLE_RCON=true dans le Deployment + mot de passe via Secret.
NAMESPACE ?= mineshark

cmd: ## Envoie une commande MC au main via RCON. Usage: make cmd ARGS="say hello"
	@test -n "$(ARGS)" || (echo "❌ Usage: make cmd ARGS=\"<commande MC>\""; exit 1)
	@kubectl exec -n $(NAMESPACE) deploy/mc-main -- rcon-cli $(ARGS)

op: ## Donne OP à un joueur. Usage: make op PLAYER=Zoyern
	@test -n "$(PLAYER)" || (echo "❌ Usage: make op PLAYER=<pseudo>"; exit 1)
	@kubectl exec -n $(NAMESPACE) deploy/mc-main -- rcon-cli op $(PLAYER)
	@echo "✓ $(PLAYER) est maintenant OP."

deop: ## Retire OP à un joueur. Usage: make deop PLAYER=Zoyern
	@test -n "$(PLAYER)" || (echo "❌ Usage: make deop PLAYER=<pseudo>"; exit 1)
	@kubectl exec -n $(NAMESPACE) deploy/mc-main -- rcon-cli deop $(PLAYER)

console: ## Shell RCON interactif (tape les commandes MC une par une, Ctrl+D pour quitter)
	@kubectl exec -n $(NAMESPACE) -it deploy/mc-main -- rcon-cli


# ─── Schematics (assets/schematics/ → pod mc-main) ─────────────────
# On commit les .schematic dans le repo sous assets/schematics/ pour
# les avoir en gitops. `push-schematics` les copie dans le pod vers
# /data/plugins/WorldEdit/schematics/ (accessibles via //schem load).
push-schematics: ## Copie assets/schematics/*.schematic vers le pod mc-main
	@test -d assets/schematics \
	    || (echo "❌ assets/schematics/ inexistant"; exit 1)
	@pod=$$(kubectl get pod -n $(NAMESPACE) -l app=mc-main \
	    -o jsonpath='{.items[0].metadata.name}'); \
	 test -n "$$pod" \
	    || (echo "❌ Pas de pod mc-main trouvé. make status ?"; exit 1); \
	 kubectl exec -n $(NAMESPACE) $$pod -- \
	    mkdir -p /data/plugins/WorldEdit/schematics; \
	 for f in assets/schematics/*.schematic assets/schematics/*.schem; do \
	     [ -f "$$f" ] || continue; \
	     name=$$(basename "$$f"); \
	     echo "  ▶ $$name"; \
	     kubectl cp "$$f" \
	         $(NAMESPACE)/$$pod:/data/plugins/WorldEdit/schematics/$$name; \
	 done
	@echo "✓ Schematics poussés. En jeu : //schem list"


# ─── Mise à jour des plugins + serveur Paper ───────────────────────
# itzg cache les jars (Paper, plugins Modrinth/Spiget/Geyser) dans le
# PVC. Même si une nouvelle version existe, le jar existant reste tant
# qu'on ne le supprime pas. Cette cible force un re-download complet.
#
# Ce qui est supprimé :
#   • paper-*.jar         → itzg redownload la dernière build 1.21.4
#   • plugins/*.jar       → Modrinth/Spiget/URL direct retéléchargent
# Ce qui est conservé :
#   • mondes (hub/, etc.)
#   • plugins/<Plugin>/   (configs des plugins)
#   • usercache, ops.json, bans, etc.
update-plugins: ## Force le re-download de Paper + tous les plugins (conserve mondes et configs)
	@pod=$$(kubectl get pod -n $(NAMESPACE) -l app=mc-main \
	    -o jsonpath='{.items[0].metadata.name}'); \
	 test -n "$$pod" \
	    || (echo "❌ Pas de pod mc-main trouvé."; exit 1); \
	 echo "▶ Pod cible : $$pod"; \
	 echo "▶ Arrêt propre du serveur…"; \
	 kubectl exec -n $(NAMESPACE) $$pod -- rcon-cli save-all >/dev/null 2>&1 || true; \
	 kubectl exec -n $(NAMESPACE) $$pod -- rcon-cli stop >/dev/null 2>&1 || true; \
	 sleep 5; \
	 echo "▶ Suppression des jars cachés (Paper + plugins)…"; \
	 kubectl exec -n $(NAMESPACE) $$pod -- sh -c ' \
	     rm -f /data/paper-*.jar /data/purpur-*.jar 2>/dev/null; \
	     rm -f /data/plugins/*.jar 2>/dev/null; \
	     echo "  ✓ Jars supprimés (les configs plugins/<Plugin>/ sont intactes)" \
	 '
	@kubectl rollout restart deploy/mc-main -n $(NAMESPACE)
	@echo "✓ Redémarrage en cours. itzg retélécharge tout. Suis : make logs-main"


# ─── Wipe des mondes parasites du PVC ──────────────────────────────
# Supprime du PVC mc-main les mondes auto-générés ou hérités d'anciens
# tests (world*, hub_the_end, hub_nether). Multiverse mémorise les
# mondes connus dans worlds.yml — on l'efface aussi pour éviter qu'il
# les ré-importe au prochain boot.
#
# ⚠️ NE TOUCHE PAS au monde `hub` (le seul qu'on garde).
# Pour wipe AUSSI hub : ajoute INCLUDE_HUB=1.
wipe-worlds: ## Supprime les mondes parasites du PVC mc-main (world*, *_the_end, *_nether)
	@pod=$$(kubectl get pod -n $(NAMESPACE) -l app=mc-main \
	    -o jsonpath='{.items[0].metadata.name}'); \
	 test -n "$$pod" \
	    || (echo "❌ Pas de pod mc-main trouvé. make status ?"; exit 1); \
	 echo "▶ Pod cible : $$pod"; \
	 echo "▶ Arrêt du serveur Minecraft (sauvegarde + stop propre)…"; \
	 kubectl exec -n $(NAMESPACE) $$pod -- rcon-cli save-all >/dev/null 2>&1 || true; \
	 kubectl exec -n $(NAMESPACE) $$pod -- rcon-cli stop >/dev/null 2>&1 || true; \
	 echo "▶ Attente 5s pour flush des chunks…"; sleep 5; \
	 echo "▶ Suppression des mondes parasites :"; \
	 for w in world world_nether world_the_end hub_nether hub_the_end; do \
	     kubectl exec -n $(NAMESPACE) $$pod -- sh -c "test -d /data/$$w && rm -rf /data/$$w && echo '  ✓ $$w'" 2>/dev/null \
	         || echo "  · $$w (absent)"; \
	 done
	@if [ "$(INCLUDE_HUB)" = "1" ]; then \
	     pod=$$(kubectl get pod -n $(NAMESPACE) -l app=mc-main -o jsonpath='{.items[0].metadata.name}'); \
	     echo "▶ INCLUDE_HUB=1 : suppression de hub/ aussi"; \
	     kubectl exec -n $(NAMESPACE) $$pod -- rm -rf /data/hub && echo "  ✓ hub"; \
	 fi
	@pod=$$(kubectl get pod -n $(NAMESPACE) -l app=mc-main -o jsonpath='{.items[0].metadata.name}'); \
	 echo "▶ Reset mémoire Multiverse (worlds.yml / worlds2.yml)…"; \
	 kubectl exec -n $(NAMESPACE) $$pod -- sh -c \
	     "rm -f /data/plugins/Multiverse-Core/worlds.yml /data/plugins/Multiverse-Core/worlds2.yml" \
	     && echo "  ✓ Multiverse oubliera les anciens mondes au prochain boot"
	@echo "▶ Restart pod mc-main…"
	@kubectl rollout restart deploy/mc-main -n $(NAMESPACE)
	@echo "✓ Wipe terminé. Suis l'état : make logs-main"


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


.PHONY: ssh deploy backup gen-secrets show-secrets doctor init ci-lint old-server-reset old-server-prep old-server-run cmd op deop console push-schematics wipe-worlds update-plugins
