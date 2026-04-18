# MineShark — Mémoire projet

Source de vérité des décisions prises avec Alexis. À lire en début de session pour éviter de re-débattre.

## Stack validée (2026-04-17)

- **Proxy** : Velocity (itzg/mc-proxy:java21), SEUL point d'entrée public.
- **Serveur principal** : Paper (itzg/minecraft-server:java21) — lobby + survie, derrière Velocity.
- **Serveur moddé** : NeoForge, standalone (port 25566), PAS derrière Velocity (incompat protocole).
- **Bedrock cross-play** : Geyser + Floodgate (plugins sur le proxy).
- **Reverse-proxy web** : Traefik (décision finale, cf. plus bas). Pas Nginx.
- **Infra** : Docker Compose en dev local, K3s sur VPS Netcup KVM en prod.
- **Langage plugins** : Java d'abord (3-4 semaines), Kotlin ensuite. Kotlin = data classes, null-safety compilo, coroutines ; Java = standard MC, tous les tutos. Kotlin compile vers bytecode Java donc 100% compat.

## Choix de fork Paper

Alexis a choisi **Purpur** pour le serveur principal. Hiérarchie : Paper ⊂ Pufferfish ⊂ Purpur.
- **Paper** : la base, 99% compat plugins.
- **Pufferfish** : fork Paper, +10-20% perf, un peu moins testé.
- **Purpur** : fork Pufferfish + features gameplay (double-jump, AFK, flying lobby). **Choix Alexis**.
- **Folia** : multi-thread régionalisé, jeune, plugins incompat → pas pour nous.
- **Leaves** : fork Paper + Bedrock natif intégré. Prometteur mais jeune.

**Sur Leaves** (question du 2026-04-17) : non pas encore. Geyser+Floodgate sur Velocity sont matures, production-ready, documentés. Leaves ferait doublon avec notre bridge actuel. À re-évaluer dans 1 an si Leaves gagne en traction.

## Recoder Paper / Hydraulic : décision = NON

- Paper = ~1M lignes Java, patchés à chaque release MC (2-3 semaines).
- Bridge Bedrock natif = UDP RakNet vs Java TCP, années de dev ingénieur senior.
- "Un jeune a fait le bridge Hytale↔Minecraft" : Hytale↔MC est plus simple (deux protocoles modernes, pas de legacy Bedrock RakNet, pas de contraintes anti-cheat Mojang). Pas comparable.
- **Stratégie** : Paper/Purpur + Geyser + plugins custom par-dessus. Si un besoin spécifique émerge (ex: Skywars custom), on écrit UN plugin focalisé, pas un fork.

## Multiverse-core custom : décision = NON (sauf couche custom par-dessus)

- Multiverse gère déjà : mondes, permissions par monde, inventaires séparés, gamemode par monde, portails.
- Réécrire = 500-1000h pour réinventer. Mieux : nos propres plugins (SkywarsCustom, etc.) qui **utilisent** l'API Multiverse pour créer/détruire des arènes.

## Architecture mondes (lobby + mini-games)

- Lobby = un monde Multiverse en adventure (sans plugin côté lobby, juste la config Multiverse).
- Chaque mini-game = un monde Multiverse avec ses rules (`mv modify set gamemode survival skywars-desert`).

## CI/CD + branches (décision 2026-04-17)

Flow GitFlow simplifié :
- `main` = prod, jamais de commit direct, CD auto sur VPS.
- `dev` = intégration, PR depuis les features.
- `feature/<nom>` = une feature en cours → PR vers `dev`.

Lint CI/CD attaché à `make` : `make re` en local ET reproduit en CI (make/admin.mk `ci-lint`).
`make deploy` = `git push && ssh VPS 'git pull && make re'`.

## Sécurité conteneurs (appliqué 2026-04-17)

Tous les conteneurs tournent en **non-root UID 1000:1000** :
- Docker Compose : `user: "1000:1000"` + `security_opt: no-new-privileges`.
- K8s : `securityContext` pod (`runAsNonRoot: true`, `runAsUser/Group: 1000`, `fsGroup: 1000`) + container (`allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`).
- `make init` aligne `data/` et `backups/` en `1000:1000` (variable `CONTAINER_UID/GID` override possible).

## Traefik vs Nginx

Décision = Traefik. Raison pratique : auto-discovery Docker/K8s via labels, Let's Encrypt natif, API dashboard. Timeouts WebSocket = équivalents à Nginx côté robustesse, juste une config différente. Pas d'avantage Nginx pour notre cas d'usage.

## Makefile — conventions

- `:=` = assignation immédiate (évaluée une fois au parsing). Utilisé par défaut car plus rapide, plus prévisible.
- `=` = lazy (ré-évaluée à chaque usage). À éviter sauf besoin précis (ex: dépend d'une var qui change).
- `?=` = assigne seulement si pas déjà défini. Utilisé pour les valeurs par défaut surchargeables par `.env` (VPS_USER, CONTAINER_UID, etc.).
- `+=` = append.
- `.DEFAULT_GOAL := help` = explicite. Sans ça, Make prend la première target (tradition C/42 = `all`). On préfère l'explicite.

## VPS / KVM

VPS Netcup KVM = vCPU partagés mais garantis, pas sursouscrits comme OVH. Pas de bare-metal, mais perfs stables. Dédié vrai = gamme "Dedicated Server" (DS), 2-5x plus cher. Pas nécessaire pour notre charge.

## Ancien serveur (mc-server-old) — migration maps 1.8 → 1.21

**État confirmé** (logs 2026-04-17 18:42→18:50) : serveur bootable, 43 mondes chargent, 1 seul corrompu (`build`). Le reste est récupérable.

### Faits établis

- **JAR** : `spigot-1.8.7.jar` (pas 1.8.8). Commande : `java -Xmx2G -jar spigot-1.8.7.jar nogui`.
- **Port** : `server.properties → server-port=12734`. C'est pour ça que `localhost:25565` donne Connection refused. **Se connecter sur `localhost:12734`** avec un client **Minecraft 1.8.9** (protocole 47, compatible Spigot 1.8.7).
- **Boot lent** (~7 min 20s) : Multiverse charge les 43 mondes d'un coup, chacun pré-génère son spawn. Le script `scripts/old-server-prep.sh` (alias `make old-server-prep`) bascule `autoload: false` pour tous sauf `swr` → ~30s de boot. `/mv load <map>` à la demande ensuite.
- **Warnings à ignorer** : `TileEntityCommand at X,Y,Z (AIR)` = command blocks orphelins, pas de la corruption. `Preparing spawn area` = normal.
- **Vraie erreur** : `[Multiverse-Core] The world 'build' could NOT be loaded because it contains errors!` — 1 map corrompue sur 43. À inspecter avec MCAselector ou laisser tomber.
- **Ctrl+C ne marche pas** : Spigot 1.8 n'intercepte pas SIGINT proprement. Utiliser `stop` dans la console, ou `kill <PID>` depuis un autre terminal (SIGTERM d'abord).
- **Logs propres** : `java ... 2>&1 | tee logs/migration.log` → fichier lisible ensuite pour diagnostic.

### Mondes identifiés dans worlds.yml

43 mondes. Génériques : `world`, `world_nether`, `world_the_end`. Gameplay hébergés : `swr` (principal), `lobby`, `lobbyswr`, `spawn`, `spawnskywars`, `sgspawn`, `skyworld` (générateur uSkyBlock manquant → FLAT en fallback pour les chunks neufs, existants OK), `MapSkyblock`, maps SurvivalGames (`SurvivalGames4`), SkyWars (`sw1`..`sw9`, + `caves_1`, `jungle_2`, `jungle_6`, `pirates_3`, `forest_4`, `hotairballoons_5`, `bone_7` via SkyWarsReloaded), `build` (corrompu).

### Helpers ajoutés

- `mc-server-old-backup.zip` (racine du repo) = **cold backup de référence** de l'ancien serveur (archive prise serveur arrêté, état cohérent, fichiers jamais modifiés). Source de vérité pour un reset propre.
- `make old-server-reset` — archive le `mc-server-old/` courant dans `backups/old-server-pre-reset-<ts>.tar.gz` puis restaure depuis le zip.
- `scripts/old-server-prep.sh` (alias `make old-server-prep`) — cold backup interne + patch `worlds.yml` (autoload=false sauf swr) + patch `spigot.yml` (bungeecord=false). Idempotent.
- `make old-server-run` — lance le serveur avec log tee'é vers `mc-server-old/logs/migration.log`.

### Erreur BungeeCord IP forwarding (résolue 2026-04-17)

Symptôme : `lost connection: If you wish to use IP forwarding, please enable it in your BungeeCord config as well!`. Cause : `mc-server-old/spigot.yml` avait `settings.bungeecord: true` (l'ancien serveur vivait derrière un BungeeCord en 2016). En mode migration, pas de proxy devant → il faut `bungeecord: false`. Patché automatiquement par `old-server-prep.sh` depuis cette date.

### Séquence migration canonique

```bash
make old-server-reset    # repart du zip (état vierge garanti)
make old-server-prep     # patches autoload + bungeecord (idempotent)
make old-server-run      # boot ~30s, client MC 1.8.9 → localhost:12734
```
Priorité Alexis = identifier LE lobby principal, `//schem save lobby-main fast`, deploy VPS via `make deploy`, `//schem load lobby-main` + `//paste -a` sur le serveur 1.21.x.

## Audit projet dev+prod (2026-04-17 → tranché 2026-04-18)

Points identifiés et résolus dans la session du 2026-04-17/18 :

- **✅ PAPER → PURPUR partout** — `docker-compose.yml` et `k8s/main/deployment.yaml` basculés sur `TYPE: PURPUR`. `.env.example` documente le choix (`SERVER_TYPE=PURPUR`). Doc : `docs/forks-comparison.md`.
- **✅ `.env` secrets** — `RCON_PASSWORD` ne vit plus qu'à runtime : injecté par `make docker-up` depuis `data/secrets/rcon.secret`. Plus aucun secret en dur dans `.env` tracé. `CF_API_KEY` reste à `change-me` dans `.env.example` (manuel).
- **✅ Mod = Java only** — décision Alexis 2026-04-18 : ModdedTogether ne tourne pas en Bedrock, donc Geyser/Floodgate reste sur le proxy seulement, le serveur moddé reste Java pur. Pas de changement k8s/mod.
- **✅ `.env.ci`** — gitignoré (l10 `.gitignore`) + fichier remplacé par un stub deprecation. L'unlink Windows reste à faire manuellement (virtiofs FUSE ne permet pas la suppression côté sandbox).
- **✅ anti-xray activé** — `config/paper-global.yml` : `enable-item-obfuscation: true` + engine-mode: 4. Actif d'office.
- **✅ livenessProbe main** — bumpée à 180s (+ readinessProbe à 90s + failureThreshold: 3). Purpur boot lent au 1er start.

Bons points maintenus : non-root partout, capabilities drop [ALL], secrets k8s via SecretRef, main en ClusterIP interne, Aikar flags, `.gitignore` complet, CI lint étendue (yamllint config/, shellcheck, secrets-check).

## Setup pro lobby + serveur (2026-04-18)

### Fichiers `config/` ajoutés

- **`config/paper-global.yml`** — anti-xray activé (engine-mode 4), chunk queue tuning, Velocity section, watchdog étendu, spam-limiter.
- **`config/paper-world-defaults.yml`** — entity caps (despawn 32/128), hopper cooldown, alternate-current redstone (x10 perf), keep-spawn-loaded lobby.
- **`config/purpur.yml`** — AFK detection (tick-nearby-entities: false), villager lobotomize (gros gain perf villes), respawn anchor End, double-jump OFF global (override per-world lobby), `/uptime` + `/ping` activés.

Ces fichiers sont montés read-only par Compose et copiés dans `/data/config/` par itzg au 1er boot (via `COPY_CONFIG_DEST=/data`). En K8s, ils vivent dans la ConfigMap `mineshark-paper-config`, synchronisée par `make sync-paper-config`.

### Stack plugins "pro" étendue

`PLUGINS_MODRINTH` final (synced entre `.env.example`, `docker-compose.yml`, `k8s/main/deployment.yaml`) :
`luckperms, vault, essentialsx, worldedit, worldguard, coreprotect, multiverse-core, decent-holograms, placeholderapi, spark, chunky, floodgate, protocollib`.

Plus via `PLUGINS:` (URL directe) : Floodgate Spigot + ViaVersion 5.8.0 + ViaBackwards 5.8.1 (permet aux clients 1.8→1.21 de se connecter).

### ConfigMap K8s `mineshark-paper-config`

- Fichier squelette committé : `k8s/main/configmap.yaml` (placeholder minimal).
- Rempli en prod par `make sync-paper-config` qui fait `kubectl create configmap --from-file=config/*.yml`.
- Mount `optional: true` pour que `kubectl apply -f k8s/main/` passe même avant le 1er sync.
- Intégré dans `make up` (enchaîne `sync-velocity-config` + `sync-paper-config` + `_apply`).

### Docs ajoutées

- `docs/forks-comparison.md` — Paper ⊂ Pufferfish ⊂ Purpur, Leaves, Folia. Tableau perf/compat/maturité, raison du choix Purpur, migration via `SERVER_TYPE`.
- `docs/lobby-setup.md` — création monde Multiverse lobby, double-jump per-world, WorldGuard safe-zone, NPC DecentHolograms+armor_stand, LuckPerms vip/admin, fly VIP contexte world=lobby, checklist ouverture publique.

## CI améliorée (2026-04-18)

`.github/workflows/lint.yml` gagne deux jobs :
- **shellcheck** sur `scripts/*.sh` (level warning — attrape les bugs, pas les nits).
- **secrets-check** : `git ls-files --error-unmatch .env` et `data/secrets/` → fail si trackés.

`make/admin.mk:ci-lint` suit la même logique en local (+ étend yamllint à `config/`).

## État cleanup repo (2026-04-18)

**Ghost virtiofs** : le répertoire `mc-server-old/` est dans un état inconsistant après un `old-server-reset` buggé (FUSE Windows ne permet pas `rm`/`mv`/`shutil`). Fichiers du zip extraits par erreur à la racine du repo (`.bashrc`, `ops.json`, `build/`, `lobby/`, `swr/`, etc.). Doivent être nettoyés depuis l'Explorateur Windows — pas depuis Cowork.

Cf. `docs/cleanup-manual.md` pour la procédure complète.

## À faire / en cours

- [ ] **Cleanup manuel Windows** : supprimer `mc-server-old/` ghost + fichiers à la racine (cf. `docs/cleanup-manual.md`).
- [ ] Tester `make docker-up` avec les user:"1000:1000" appliqués (chown peut nécessiter sudo sur certaines installs).
- [ ] Créer branche `dev` + PR workflow.
- [ ] Export schematics : lobby d'abord (priorité), puis les 41 autres mondes non corrompus.
- [ ] Déployer stack Purpur sur VPS (prod) : `make deploy` puis `make sync-paper-config`.

## Préférences Alexis

- Code propre avant perf : lisibilité + convention > optimisation prématurée.
- Explications techniques vulgarisées quand un mot de jargon apparaît.
- Token-efficient mais performant : pas de ceremony inutile, mais pas de shortcut qui casse la qualité.
- Veut comprendre le "pourquoi" (`:=` vs `=`, KVM, WebSocket timeout…), pas juste suivre une recette.
