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


# ─── Déploiement à distance (asynchrone) ───────────────────────────
# `make deploy` ne BLOQUE PLUS ta console pendant le rollout (qui peut
# durer 3-5 min). Il :
#   1. git push local
#   2. SSH vers le VPS → git pull + lance scripts/deploy.sh en nohup
#   3. Rend la main en ~3s avec l'ID du log créé
#
# Tu suis l'avancement quand TU veux avec `make deploy-logs` (tail -f)
# ou `make deploy-status` (état résumé + pods).
#
# Explication du "bug reload plugins pas clean" :
#   `make re` = fclean + up = supprime deployments/services/configmaps/
#   secrets puis réapplique. Les PVC restent → les jars plugins *aussi*.
#   itzg, au reboot, voit que `/data/plugins/FooPlugin-1.2.jar` existe
#   déjà et NE RE-TÉLÉCHARGE PAS. D'où FORCE=1 qui wipe + redownload.
#
# Usages :
#   make deploy            → soft : code K8s / config changé, plugins OK
#   make deploy FORCE=1    → dur : wipe plugins, itzg retélécharge tout
#   make deploy-logs       → tail -f du dernier log deploy
#   make deploy-status     → en cours ? terminé ? pods up ?
#   make deploy FOLLOW=1   → lance ET suit (revient au comportement sync)
deploy: ## Push git + pull + rollout async sur VPS. FORCE=1 force plugins. FOLLOW=1 pour suivre.
	@echo "▶ git push…"
	@git push
	@echo "▶ Lancement du déploiement en arrière-plan sur $(VPS_IP)…"
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) '\
	    set -e; \
	    cd /opt/mineshark; \
	    git pull --ff-only --quiet; \
	    chmod +x scripts/deploy.sh 2>/dev/null || true; \
	    mkdir -p logs; \
	    ts=$$(date +%Y%m%d-%H%M%S); \
	    log="logs/deploy-$$ts.log"; \
	    ln -sf "deploy-$$ts.log" logs/deploy-latest.log; \
	    nohup env FORCE=$(FORCE) ./scripts/deploy.sh > "$$log" 2>&1 < /dev/null & \
	    disown; \
	    echo "✓ Déploiement lancé. Log : $$log"'
	@echo ""
	@if [ "$(FOLLOW)" = "1" ]; then \
	    echo "▶ FOLLOW=1 → suivi en direct (Ctrl+C pour sortir, le déploiement continue)"; \
	    $(MAKE) --no-print-directory deploy-logs; \
	 else \
	    echo "   Suivre en live : make deploy-logs"; \
	    echo "   État           : make deploy-status"; \
	 fi

deploy-logs: ## Tail -f du dernier déploiement (Ctrl+C pour sortir, le deploy continue)
	@echo "▶ tail -f logs/deploy-latest.log sur $(VPS_IP) (Ctrl+C sort du tail seulement)"
	@ssh -t -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    'cd /opt/mineshark && tail -f logs/deploy-latest.log'

deploy-status: ## État du dernier déploiement (en cours / fini / pods)
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) '\
	    cd /opt/mineshark; \
	    echo "▶ Déploiement :"; \
	    if [ -f logs/deploy.pid ] && kill -0 $$(cat logs/deploy.pid) 2>/dev/null; then \
	        echo "  ⏳ en cours (PID $$(cat logs/deploy.pid))"; \
	    else \
	        last=$$(readlink logs/deploy-latest.log 2>/dev/null || echo "(aucun)"); \
	        echo "  ✓ terminé (dernier log : $$last)"; \
	        tail -1 logs/deploy-latest.log 2>/dev/null | sed "s/^/    /"; \
	    fi; \
	    echo ""; \
	    echo "▶ Pods :"; \
	    kubectl -n $(NAMESPACE) get pods -o wide 2>/dev/null | sed "s/^/  /"'


# ─── Wrapper générique : exécuter une cible make sur le VPS ─────────
# Utile pour toutes les cibles kubectl (status, logs-*, mod-on, secrets,
# up, down, etc.) quand tu n'as pas de kubeconfig local (cas par défaut
# depuis WSL). Équivalent à se connecter en SSH et lancer la cible.
#
# Usage :
#   make remote T=status
#   make remote T=logs-main
#   make remote T=mod-on
#   make remote T="cmd ARGS=\"say Hello\""
#
# Pour les cibles les plus fréquentes, des alias dédiés existent :
#   make r-status, make r-logs-main, make r-logs-mod, make r-mod-on
remote: ## Exécute une cible make sur le VPS via SSH. Usage: make remote T=status
	@test -n "$(T)" || (echo "❌ Usage: make remote T=<cible> [args…]"; exit 1)
	@ssh -t -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    "cd /opt/mineshark && make $(T)"

# Alias pratiques pour les cibles consultatives les plus fréquentes.
r-status:    ; @$(MAKE) --no-print-directory remote T=status
r-logs-main: ; @$(MAKE) --no-print-directory remote T=logs-main
r-logs-mod:  ; @$(MAKE) --no-print-directory remote T=logs-mod
r-logs-proxy:; @$(MAKE) --no-print-directory remote T=logs-proxy
r-mod-on:    ; @$(MAKE) --no-print-directory remote T=mod-on
r-mod-off:   ; @$(MAKE) --no-print-directory remote T=mod-off


# ─── Synchronisation .env local → VPS ──────────────────────────────
# .env est gitignored (contient VPS_IP, CF_API_KEY, DISCORD_TOKEN…) →
# `git pull` sur le VPS ne le met PAS à jour automatiquement.
# Quand tu édites .env localement (ex. ajout d'un DISCORD_TOKEN) et
# que tu veux que le VPS le voie, lance `make env-sync`.
#
# Sécurité :
#   • rsync direct par SSH (chiffré de bout en bout).
#   • On copie en tmp + rename atomique → jamais de .env tronqué.
#   • On affiche un diff succinct (noms de variables changées, SANS
#     les valeurs) pour que tu valides visuellement avant le push.
#
# Tu n'es PAS obligé de `env-sync` pour `discord-setup` : cette dernière
# inline les valeurs directement via SSH. env-sync est utile quand :
#   - tu changes CF_API_KEY (lu par make secrets sur le VPS)
#   - tu changes VPS_IP / VPS_SSH_PORT (mais en pratique tu ne les
#     changes jamais sur le VPS, uniquement en local)
#   - tu veux que `make re` / `make up` sur le VPS ait les nouvelles
#     valeurs .env sans passer par les cibles *-setup dédiées
env-sync: ## Copie le .env local vers /opt/mineshark/.env sur le VPS (après confirmation)
	@test -f .env || (echo "❌ .env local absent"; exit 1)
	@echo "▶ .env local → $(VPS_USER)@$(VPS_IP):$(VPS_REMOTE_ROOT)/.env"
	@echo "  Diff des noms de variables (valeurs masquées) :"
	@diff \
	    <(grep -E '^[A-Z_]+=' .env 2>/dev/null | cut -d= -f1 | sort) \
	    <(ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	        "grep -E '^[A-Z_]+=' $(VPS_REMOTE_ROOT)/.env 2>/dev/null" \
	      | cut -d= -f1 | sort) \
	    | sed 's/^/    /' || true
	@printf "  Continuer le push ? [y/N] "
	@read ans; test "$$ans" = "y" || test "$$ans" = "Y" || (echo "  Annulé."; exit 1)
	@# Push atomique : scp vers un .env.tmp puis mv. Si scp échoue au
	@# milieu, le .env existant reste intact.
	@scp -P $(VPS_SSH_PORT) -q .env \
	    "$(VPS_USER)@$(VPS_IP):$(VPS_REMOTE_ROOT)/.env.tmp"
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    "mv $(VPS_REMOTE_ROOT)/.env.tmp $(VPS_REMOTE_ROOT)/.env && chmod 600 $(VPS_REMOTE_ROOT)/.env"
	@echo "✓ .env synchronisé (chmod 600). Pour appliquer les changements"
	@echo "  côté K8s : make deploy FORCE=1  (ou make discord-setup si"
	@echo "  c'était juste les DISCORD_*)"


# ─── Bridge Discord — wrappers SSH ─────────────────────────────────
# Ces cibles sont pensées pour être lancées DEPUIS TA MACHINE LOCALE
# (WSL / Mac / Linux). Elles SSH-wrappent les opérations kubectl qui
# tournent sur le VPS — pas besoin d'installer kubectl localement, pas
# besoin de `make ssh` à la main.
#
# Architecture rappel (détail dans docs/discord.md) :
#   .env local  ─(make discord-setup)─>  SSH  ─>  kubectl create secret
#                                                      discord-chat-mod-config
#                                                → rollout restart mc-mod
#                                                → initContainer patch TOML
#
# Le token/guild-id/channel-id sont transmis **via SSH** au moment
# d'exécuter kubectl. Ils n'atterrissent PAS dans le .env du VPS,
# uniquement dans le Secret K8s (base64-obfusqué). Si tu veux aussi
# que le .env du VPS les contienne (pour `make up` standalone) : lance
# `make env-sync` en plus.

discord-setup: ## (Depuis LOCAL) Pousse DISCORD_* du .env local → Secret K8s sur VPS + redémarre mc-mod
	@echo "▶ Vérification du .env local …"
	@test -n "$(DISCORD_TOKEN)" \
	    || (echo "❌ DISCORD_TOKEN vide dans .env local — voir docs/discord.md"; exit 1)
	@test -n "$(DISCORD_GUILD_ID)" \
	    || (echo "❌ DISCORD_GUILD_ID vide dans .env local"; exit 1)
	@test -n "$(DISCORD_CHANNEL_ID)" \
	    || (echo "❌ DISCORD_CHANNEL_ID vide dans .env local"; exit 1)
	@echo "  ✓ token / guild-id / channel-id présents"
	@echo "▶ SSH → (re)création du Secret discord-chat-mod-config sur le VPS …"
	@# Le bloc SSH : crée le namespace si absent + (re)crée le Secret en
	@# idempotent via `kubectl apply` + rollout restart. Si mc-mod n'est
	@# pas déployé (replicas=0), le rollout restart log juste un warning,
	@# non bloquant. Les DISCORD_* sont transmis au VPS via l'argument
	@# SSH (pas via env SSH pour éviter les conflits avec ta shell locale).
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    "kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml \
	        | kubectl apply -f - >/dev/null && \
	     kubectl create secret generic discord-chat-mod-config \
	        --namespace=$(NAMESPACE) \
	        --from-literal=token='$(DISCORD_TOKEN)' \
	        --from-literal=guild-id='$(DISCORD_GUILD_ID)' \
	        --from-literal=channel-id='$(DISCORD_CHANNEL_ID)' \
	        --dry-run=client -o yaml | kubectl apply -f - && \
	     kubectl -n $(NAMESPACE) rollout restart deployment/mc-mod 2>/dev/null \
	        || echo '  ℹ️  mc-mod pas encore déployé — le patch s'\\''appliquera au 1er make r-mod-on'"
	@echo "✓ Secret Discord à jour sur le VPS. Vérifier : make discord-status"

discord-status: ## (Depuis LOCAL) Vérifie que le bot Discord est connecté (parse les logs mc-mod via SSH)
	@echo "▶ SSH → recherche des traces discord_chat_mod dans les logs mc-mod …"
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    "kubectl -n $(NAMESPACE) logs deployment/mc-mod -c minecraft --tail=500 2>/dev/null \
	        | grep -E '(discord_chat_mod|JDA|Token may not)' \
	        | tail -20" \
	    || echo "  ⚠️  Aucune trace — le pod tourne-t-il ? make r-status"
	@echo ""
	@echo "  ✓ \"JDA ... Finished Loading!\"     → bot connecté"
	@echo "  ❌ \"Token may not be empty\"        → Secret pas injecté / token vide"
	@echo "  ❌ \"401 Unauthorized\"              → token invalide ou révoqué"
	@echo "  (rien du tout)                      → pod pas démarré ou mod pas chargé"

discord-test: ## (Depuis LOCAL) Envoie un message de test MC → Discord via RCON (SSH-wrappé)
	@echo "▶ SSH → envoi \"[TEST] MineShark → Discord\" via RCON mc-mod …"
	@ssh -p $(VPS_SSH_PORT) $(VPS_USER)@$(VPS_IP) \
	    "kubectl -n $(NAMESPACE) exec deployment/mc-mod -c minecraft -- \
	        rcon-cli say '[TEST] MineShark → Discord'"
	@echo "✓ Message envoyé. Vérifie qu'il apparaît dans ton salon Discord."
	@echo "  S'il n'apparaît pas : make discord-status"


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
	@# ─── VPS : détecter le placeholder par défaut 127.0.0.1 ─────────
	@# Cause #1 historique du `ssh: Connection timed out port 22` après
	@# un `cp .env.example .env` incomplet : VPS_IP=127.0.0.1 par défaut.
	@if [ -f .env ] && grep -qE '^VPS_IP=127\.0\.0\.1$$' .env; then \
	    echo "  ⚠️  VPS_IP=127.0.0.1 (placeholder .env.example) — édite .env avec l'IP réelle du VPS"; \
	    echo "     sinon make deploy / make env-sync / make discord-* vont timeout."; \
	 elif [ -f .env ] && grep -qE '^VPS_IP=' .env; then \
	    ip=$$(grep -E '^VPS_IP=' .env | head -1 | cut -d= -f2); \
	    echo "  ✓ VPS_IP=$$ip"; \
	 fi
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


.PHONY: ssh vps-get vps-put \
        deploy deploy-logs deploy-status \
        remote r-status r-logs-main r-logs-mod r-logs-proxy r-mod-on r-mod-off \
        env-sync \
        discord-setup discord-status discord-test \
        plugins-sync redeploy-plugins update-plugins wipe-worlds push-schematics \
        backup gen-secrets show-secrets doctor init ci-lint \
        old-server-reset old-server-prep old-server-run \
        cmd op deop console