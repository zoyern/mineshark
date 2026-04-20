# ═══════════════════════════════════════════════════════════════════
#  make/admin.mk — Utilitaires d'administration
# ═══════════════════════════════════════════════════════════════════
#  Cibles transverses : SSH au VPS, backup, vérifications, déploiement
#  par git push, gestion des secrets auto-générés.
# ═══════════════════════════════════════════════════════════════════

# Valeurs par défaut si .env absent (le `?=` ne définit que si non set)
VPS_USER     ?= mineshark
VPS_IP       ?= 159.195.146.234
VPS_SSH_PORT ?= 2222

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


# ─── Transfert de fichiers VPS ↔ local (debug / inspection) ────────
# Zone de travail locale non-trackée : ./scratch/ (cf. .gitignore).
# Utile pour tirer un log/dump du VPS pour l'analyser sans polluer le
# repo, ou pour pousser rapidement un fichier patché sans commit.
#
# Usage :
#   make vps-get FILE=out_moded.txt              # /opt/mineshark/out_moded.txt → scratch/
#   make vps-get FILE=/var/log/syslog            # chemin absolu supporté
#   make vps-get FILE=logs/app.log DEST=backups  # override dossier local
#   make vps-put FILE=scratch/fix.yaml           # scratch/fix.yaml → /opt/mineshark/
#   make vps-put FILE=scratch/fix.yaml DEST=/tmp # override dossier distant
#
# Conventions :
#   • côté VPS, un chemin relatif est résolu sous VPS_REMOTE_ROOT
#     (défaut : /opt/mineshark, racine du repo sur le VPS)
#   • côté local, les fichiers récupérés atterrissent dans SCRATCH_DIR
#   • le port SSH est lu depuis .env (VPS_SSH_PORT) — aucun flag à taper
SCRATCH_DIR     ?= scratch
VPS_REMOTE_ROOT ?= /opt/mineshark

vps-get: ## Récupère un fichier du VPS dans ./scratch/. Usage: make vps-get FILE=<chemin> [DEST=<dir_local>]
	@test -n "$(FILE)" || (echo "❌ Usage: make vps-get FILE=<chemin_distant> [DEST=<dir_local>]"; exit 1)
	@local_dest="$${DEST:-$(SCRATCH_DIR)}"; \
	 mkdir -p "$$local_dest"; \
	 case "$(FILE)" in \
	     /*) remote="$(FILE)" ;; \
	     *)  remote="$(VPS_REMOTE_ROOT)/$(FILE)" ;; \
	 esac; \
	 echo "▶ scp $(VPS_USER)@$(VPS_IP):$$remote → $$local_dest/"; \
	 scp -P $(VPS_SSH_PORT) "$(VPS_USER)@$(VPS_IP):$$remote" "$$local_dest/" \
	     && echo "✓ Récupéré dans $$local_dest/"

vps-put: ## Envoie un fichier local sur le VPS. Usage: make vps-put FILE=<chemin_local> [DEST=<dir_distant>]
	@test -n "$(FILE)" || (echo "❌ Usage: make vps-put FILE=<chemin_local> [DEST=<dir_distant>]"; exit 1)
	@test -f "$(FILE)" || (echo "❌ Fichier local introuvable : $(FILE)"; exit 1)
	@remote_dest="$${DEST:-$(VPS_REMOTE_ROOT)}"; \
	 echo "▶ scp $(FILE) → $(VPS_USER)@$(VPS_IP):$$remote_dest/"; \
	 scp -P $(VPS_SSH_PORT) "$(FILE)" "$(VPS_USER)@$(VPS_IP):$$remote_dest/" \
	     && echo "✓ Poussé vers $(VPS_USER)@$(VPS_IP):$$remote_dest/"


# ─── Déploiement à distance ────────────────────────────────────────
# Explication du "bug reload plugins pas clean" :
#   `make deploy` → git push + git pull (VPS) + `make re`.
#   `make re` = fclean + up = supprime deployments/services/configmaps/
#   secrets puis réapplique. Les PVC restent → les jars plugins *aussi*.
#   itzg, au reboot, voit que `/data/plugins/FooPlugin-1.2.jar` existe
#   déjà et NE RE-TÉLÉCHARGE PAS (même si une version plus récente est
#   dispo sur Modrinth/Spiget). Résultat : tu modifies .env pour ajouter
#   un plugin ou bumper une version → `make deploy` ne le reflète pas.
#
# Deux usages distincts :
#   make deploy            → soft : code K8s / config changé, plugins OK
#   make deploy FORCE=1    → dur : wipe tous les jars plugins puis `re`,
#                            itzg retélécharge depuis Modrinth/Spiget/URL
#                            (≡ `make re` + `make update-plugins` côté VPS).
#   make redeploy-plugins  → idem FORCE=1 mais sans passer par `make re`
#                            (juste rollout restart, plus rapide).
deploy: ## Push git + pull + rollout sur VPS. FORCE=1 force retéléchargement plugins
	@echo "▶ git push…"
	@git push
	@if [ "$(FORCE)" = "1" ]; then \
	    echo "▶ FORCE=1 → pull + re + wipe plugins + rollout (retéléchargement complet)"; \
	    echo "   ⚠️  1er boot après fclean : 3-5 min (download Paper+plugins+gen monde)"; \
	    ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	        'cd /opt/mineshark && git pull && make re && kubectl -n $(NAMESPACE) rollout status deploy/mc-main --timeout=360s && make update-plugins'; \
	 else \
	    echo "▶ Soft deploy (plugins cached conservés — use FORCE=1 pour les rafraîchir)"; \
	    ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	        'cd /opt/mineshark && git pull && make re'; \
	 fi


# ─── Sync des plugins déposés à la main (plugins/manual/ → VPS) ─────
# Workflow complet documenté dans plugins/manual/README.md.
#
# 1) rsync plugins/manual/*.jar → /var/lib/mineshark/manual-plugins/ (VPS)
#    On utilise --delete pour que supprimer un jar localement le retire
#    aussi sur le VPS. Protège par --include='*.jar' --exclude='*' pour
#    éviter de copier README.md ou .gitkeep.
# 2) kubectl rollout restart deploy/mc-main pour que l'initContainer
#    copy-manual-plugins recopie les jars vers /data/plugins/.
#
# Prérequis : le répertoire /var/lib/mineshark/manual-plugins/ doit
# exister et être accessible au user VPS_USER (ou à root via sudo).
# Le volume k8s hostPath type=DirectoryOrCreate crée le dir au 1er
# boot du pod, mais il appartient à root → rsync écrit en tant que
# VPS_USER peut échouer. Si c'est le cas, crée-le à la main :
#
#   make ssh
#   sudo mkdir -p /var/lib/mineshark/manual-plugins
#   sudo chown -R $(VPS_USER):$(VPS_USER) /var/lib/mineshark/manual-plugins
#   exit
#
# Puis `make plugins-sync` fonctionnera en SSH user normal.
MANUAL_PLUGINS_DIR              ?= plugins/manual
MANUAL_PLUGINS_VPS_PATH         ?= /var/lib/mineshark/manual-plugins
MANUAL_BENTOBOX_ADDONS_DIR      ?= plugins/manual/bentobox-addons
MANUAL_BENTOBOX_ADDONS_VPS_PATH ?= /var/lib/mineshark/manual-bentobox-addons

plugins-sync: ## Synchronise plugins/manual/*.jar (+ addons BentoBox) vers le VPS et redémarre mc-main
	@test -d $(MANUAL_PLUGINS_DIR) \
	    || (echo "❌ $(MANUAL_PLUGINS_DIR)/ inexistant. Voir plugins/manual/README.md"; exit 1)
	@# ─ Plugins "classiques" (rang 4, cf. docs/plugins.md) ──────────────
	@count=$$(ls $(MANUAL_PLUGINS_DIR)/*.jar 2>/dev/null | wc -l); \
	 if [ "$$count" = "0" ]; then \
	     echo "ℹ️  Aucun jar dans $(MANUAL_PLUGINS_DIR)/. On sync quand même"; \
	     echo "   (utile pour purger les jars qui auraient été retirés)."; \
	 else \
	     echo "▶ $$count plugin(s) classique(s) à synchroniser :"; \
	     ls -1 $(MANUAL_PLUGINS_DIR)/*.jar | sed 's|^|    |'; \
	 fi
	@echo "▶ rsync (plugins)   → $(VPS_USER)@$(VPS_IP):$(MANUAL_PLUGINS_VPS_PATH)/ …"
	@rsync -avz --delete \
	    --include='*.jar' --exclude='*' \
	    -e "ssh -p $(VPS_SSH_PORT)" \
	    $(MANUAL_PLUGINS_DIR)/ \
	    "$(VPS_USER)@$(VPS_IP):$(MANUAL_PLUGINS_VPS_PATH)/" \
	    || (echo "❌ rsync a échoué. Causes possibles :"; \
	        echo "   a) rsync pas installé SUR LE VPS (il faut aux 2 bouts) :"; \
	        echo "        make ssh"; \
	        echo "        sudo apt install rsync -y"; \
	        echo "   b) Le dossier n'existe pas ou n'appartient pas à $(VPS_USER) :"; \
	        echo "        make ssh"; \
	        echo "        sudo mkdir -p $(MANUAL_PLUGINS_VPS_PATH)"; \
	        echo "        sudo chown -R $(VPS_USER):$(VPS_USER) $(MANUAL_PLUGINS_VPS_PATH)"; \
	        exit 1)
	@# ─ Addons BentoBox (sous-dossier dédié) ────────────────────────────
	@# Séparé car destiné à /data/plugins/BentoBox/addons/ et non à
	@# /data/plugins/. Voir initContainer copy-manual-plugins.
	@if [ -d $(MANUAL_BENTOBOX_ADDONS_DIR) ]; then \
	     acount=$$(ls $(MANUAL_BENTOBOX_ADDONS_DIR)/*.jar 2>/dev/null | wc -l); \
	     if [ "$$acount" = "0" ]; then \
	         echo "ℹ️  Aucun addon BentoBox dans $(MANUAL_BENTOBOX_ADDONS_DIR)/. Sync quand même (purge)."; \
	     else \
	         echo "▶ $$acount addon(s) BentoBox à synchroniser :"; \
	         ls -1 $(MANUAL_BENTOBOX_ADDONS_DIR)/*.jar | sed 's|^|    |'; \
	     fi; \
	     echo "▶ rsync (addons)    → $(VPS_USER)@$(VPS_IP):$(MANUAL_BENTOBOX_ADDONS_VPS_PATH)/ …"; \
	     rsync -avz --delete \
	         --include='*.jar' --exclude='*' \
	         -e "ssh -p $(VPS_SSH_PORT)" \
	         $(MANUAL_BENTOBOX_ADDONS_DIR)/ \
	         "$(VPS_USER)@$(VPS_IP):$(MANUAL_BENTOBOX_ADDONS_VPS_PATH)/" \
	         || (echo "❌ rsync addons a échoué. Fix :"; \
	             echo "   a) rsync pas installé sur le VPS ? make ssh + sudo apt install rsync -y"; \
	             echo "   b) Dossier manquant sur le VPS :"; \
	             echo "        sudo mkdir -p $(MANUAL_BENTOBOX_ADDONS_VPS_PATH)"; \
	             echo "        sudo chown -R $(VPS_USER):$(VPS_USER) $(MANUAL_BENTOBOX_ADDONS_VPS_PATH)"; \
	             exit 1); \
	 else \
	     echo "ℹ️  $(MANUAL_BENTOBOX_ADDONS_DIR)/ absent — skip (normal si pas d'addon BentoBox)"; \
	 fi
	@echo "▶ Rollout restart du pod mc-main (pour recharger les jars)…"
	@kubectl rollout restart deploy/mc-main -n $(NAMESPACE)
	@echo "✓ Sync terminée. L'initContainer copy-manual-plugins va recopier"
	@echo "  les jars dans /data/plugins/ et /data/plugins/BentoBox/addons/"
	@echo "  au prochain boot (~90s)."
	@echo "  Suivi : make logs-main  |  Vérif : make cmd ARGS=plugins"


# ─── Re-deploy "propre" des plugins (force pull Modrinth/Spiget/URL) ─
# `make deploy` (git push + pull + make re) ne force PAS un re-download
# des jars déjà présents dans le PVC : itzg ne retélécharge que si la
# version distante est > version locale (et SPIGET_UPDATE_CHECK_INTERVAL
# temporise à 72h côté Spiget). Quand tu ajoutes un plugin dans .env ou
# quand tu veux vraiment tout rebumper : lance cette cible.
#
# Différences pratiques :
#   make deploy            → git push + git pull + make re (soft reload)
#                            ⚠️ ne retélécharge PAS les plugins existants.
#   make re                → docker compose / k8s rollout restart seul,
#                            idem : pas de refresh plugins.
#   make redeploy-plugins  → git push + pull + wipe /data/plugins/*.jar
#                            + rollout → itzg retélécharge TOUT depuis
#                            Modrinth/Spiget/URL. Safe (configs gardées).
#
# Pour juste re-télécharger sans redéployer le code : make update-plugins.
redeploy-plugins: ## Push + pull + force retéléchargement complet des plugins (Modrinth/Spiget/URL)
	@echo "▶ git push…"
	@git push
	@echo "▶ SSH → git pull sur le VPS…"
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) 'cd /opt/mineshark && git pull'
	@echo "▶ Sync plugins manuels (si nouveaux jars dans plugins/manual/)…"
	@$(MAKE) --no-print-directory plugins-sync
	@echo "▶ Wipe /data/plugins/*.jar pour forcer itzg à tout retélécharger…"
	@$(MAKE) --no-print-directory update-plugins
	@echo ""
	@echo "✓ Redeploy des plugins en cours. Suis : make logs-main"
	@echo "  Vérifie après ~2min : make cmd ARGS=plugins"


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
	@# ─── Discord bridge (optionnel) ──────────────────────────────────
	@# Non bloquant : le mod se charge sans token, il log juste un WARN.
	@if [ -f .env ]; then \
	    if grep -qE '^DISCORD_TOKEN=.+$$' .env; then \
	        echo "  ✓ Discord bridge configuré (token présent)"; \
	        grep -qE '^DISCORD_GUILD_ID=.+$$'   .env || echo "  ⚠️  DISCORD_TOKEN set mais DISCORD_GUILD_ID vide"; \
	        grep -qE '^DISCORD_CHANNEL_ID=.+$$' .env || echo "  ⚠️  DISCORD_TOKEN set mais DISCORD_CHANNEL_ID vide"; \
	    else \
	        echo "  ℹ️  Discord bridge désactivé (DISCORD_TOKEN vide) — voir docs/discord.md"; \
	    fi; \
	 fi
	@echo "▶ OK."


# ─── Init dossiers locaux + secrets initiaux ───────────────────────
# UID/GID des conteneurs itzg (non-root, voir docker-compose.yml `user:`).
# Les volumes montés doivent appartenir à ce couple pour que les
# conteneurs puissent écrire sans escalade de privilèges.
CONTAINER_UID ?= 1000
CONTAINER_GID ?= 1000

init: ## Crée les dossiers data/, backups/, scratch/, .env initial et les secrets
	@mkdir -p data/velocity data/main data/mod data/secrets backups/main backups/manual $(SCRATCH_DIR)
	@touch data/.gitkeep backups/.gitkeep $(SCRATCH_DIR)/.gitkeep
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


.PHONY: ssh vps-get vps-put deploy plugins-sync redeploy-plugins backup gen-secrets show-secrets doctor init ci-lint old-server-reset old-server-prep old-server-run cmd op deop console push-schematics wipe-worlds update-plugins