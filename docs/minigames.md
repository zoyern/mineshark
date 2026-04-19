# Mini-games MineShark — TntRun & SkyWars

Guide **end-to-end** pour installer, configurer et faire tourner **TntRun** et **SkyWars** sur le serveur principal MineShark (Paper 1.21.8). Tout est auto-installé au boot du pod — pas de manipulation manuelle sur le VPS.

> **Statut du stack (avril 2026)** — les deux plugins retenus sont activement maintenus pour 1.21.x :
> - **TntRun_reloaded** par TheDev12 (SpigotMC ID 53359, compat 1.13 → 1.21.x).
> - **SkyWarsReloaded** par lukasvdgaag (SpigotMC ID 69436, 1.14 → 1.21+, fork officiel repris en 2024).
>
> Les deux sont disponibles **gratuitement** sur SpigotMC et s'auto-installent via l'API Spiget → aucun téléchargement manuel nécessaire.

## Sommaire

- [Ajout d'un plugin mini-game : les 3 voies](#ajout-dun-plugin-mini-game--les-3-voies)
- [Workflow complet côté VPS](#workflow-complet-côté-vps)
- [TntRun — setup & configuration](#tntrun--setup--configuration)
- [SkyWars — setup & configuration des 11 maps](#skywars--setup--configuration-des-11-maps)
- [Intégration lobby (warps + NPC)](#intégration-lobby-warps--npc)
- [Checklist de test](#checklist-de-test)
- [Troubleshooting](#troubleshooting)
- [Références](#références)

---

## Ajout d'un plugin mini-game : les 3 voies

Selon où se trouve le plugin, on a **trois** mécaniques d'installation automatique — toutes gérées par l'image `itzg/minecraft-server`. Aucune ne nécessite de toucher au VPS à la main.

| Source | Variable | Fichier | Exemple |
|---|---|---|---|
| **Modrinth** (modrinth.com) | `MODRINTH_PROJECTS` | `.env` → `PLUGINS_MODRINTH` | `luckperms`, `chunky` |
| **SpigotMC** (spigotmc.org, free) | `SPIGET_RESOURCES` | `.env` → `PLUGINS_SPIGET` | `53359` (TntRun), `69436` (SkyWars) |
| **URL directe** (GitHub, CDN) | `PLUGINS` | `k8s/main/deployment.yaml` | EssentialsX, ViaVersion |
| **Jar à la main** (payant, disparu, custom) | `plugins/manual/` | le dossier du repo | voir [README.md](../plugins/manual/README.md) |

**Règle de choix** : toujours préférer Modrinth > Spiget > URL > manuel. Plus haut dans cette liste = moins de friction et mises à jour gérées par itzg.

**TntRun et SkyWars sont en voie Spiget** (déjà ajoutés au projet, tu n'as rien à faire — voir section suivante).

---

## Workflow complet côté VPS

Quand tu as cloné le repo sur ton VPS et que tu veux rajouter/maj un plugin, **tout passe par git + make**. Il n'y a **aucune manipulation manuelle sur le VPS** (modulo un `mkdir` initial, cf. [Troubleshooting](#troubleshooting)).

### Séquence type (voie Spiget — TntRun, SkyWars, etc.)

```
[1] Tu édites .env  →  PLUGINS_SPIGET=34315,1997,53359,69436,<nouvel_id>
[2] Tu édites       →  k8s/main/deployment.yaml → même liste dans SPIGET_RESOURCES
[3] git commit + push (local)
[4] make deploy     → push git, ssh au VPS, git pull, make re
                      → itzg retélécharge les jars au boot
                      → le plugin apparaît dans /data/plugins/
[5] make cmd ARGS=plugins   → vérifie qu'il est chargé
[6] make cmd ARGS="<commande-de-config>"   → config in-game
```

### Pour les plugins qui ne sont pas auto-téléchargeables

```
[1] Dépose le jar dans plugins/manual/
[2] git commit + push
[3] make plugins-sync
      → rsync plugins/manual/*.jar vers /var/lib/mineshark/manual-plugins/ sur VPS
      → kubectl rollout restart deploy/mc-main
      → l'initContainer copie les jars dans /data/plugins/
[4] make cmd ARGS=plugins   → vérifie
```

Détail complet dans [`plugins/manual/README.md`](../plugins/manual/README.md).

---

## TntRun — setup & configuration

**Plugin** : TntRun_reloaded (SpigotMC 53359), maintenu par TheDev12.
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto au prochain `make re` / `make deploy`.

### Étape 1 — déployer et vérifier que le plugin est chargé

```bash
# Après clone ou git pull sur VPS :
make re                         # restart mc-main, itzg DL TntRun_reloaded
make cmd ARGS=plugins           # liste des plugins chargés
#   → doit afficher "TNTRun" en vert
```

Logs attendus :
```
[TNTRun] Enabling TNTRun v1.10.X
[TNTRun] Loaded 0 arenas
```

### Étape 2 — construire la map (tour classique de TntRun)

Ton schematic `tntrun-classico.schematic` contient la tour **sans** les couches de sable/TNT. Deux possibilités :

**A) Tu pastes la tour vide puis remplis les étages en bloc :**

```
# 1) Crée un monde dédié
make cmd ARGS="mv create tntrun_arena normal -t FLAT -g FLAT -s 0"
make cmd ARGS="mv modify tntrun_arena set gamemode survival"
make cmd ARGS="mv modify tntrun_arena set pvp false"

# 2) TP et paste le schematic
make cmd ARGS="mvtp Zoyern tntrun_arena"
# En jeu (client) :
//schem load tntrun-classico
//paste -a -o
/setworldspawn

# 3) Remplis chaque étage de sable mixé TNT (effet visuel classique)
#    Sélectionne un étage entier (sol) avec //pos1 / //pos2 puis :
//set 80%sand,20%tnt
#    Répète pour chaque étage (typiquement 3 à 5 niveaux)
```

**B) Tu fais tout en WorldEdit from scratch** (si tu veux personnaliser la tour) :

```
# Par exemple, 3 étages de 20×20 espacés de 10 blocs en hauteur :
//pos1 -10 100 -10 ; //pos2 10 100 10 ; //set 80%sand,20%tnt
//pos1 -10 110 -10 ; //pos2 10 110 10 ; //set 80%sand,20%tnt
//pos1 -10 120 -10 ; //pos2 10 120 10 ; //set 80%sand,20%tnt
```

### Étape 3 — créer l'arène dans TntRun_reloaded

Le plugin fournit `/trsetup` (commandes OP, mode "setup"). En jeu :

```
/trsetup addarena classico              # crée l'arène "classico"
/trsetup setarena classico              # entre en mode édition

# Dans l'arène (tu es actuellement en édition) :
/trsetup setspawn                       # TP ici = nouveau spawn de cette arène (haut de la tour)
/trsetup setloselevel                   # TP à Y<50 et refais la commande = joueur qui descend sous ce Y meurt
/trsetup setmaxplayers 12
/trsetup setminplayers 2
/trsetup setlobby                       # TP au lobby d'attente (hors arène) et refais la commande
/trsetup finish                         # valide, sauvegarde plugins/TNTRun/arenas.yml
```

### Étape 4 — activer les dépendances soft (déjà présentes)

TntRun_reloaded utilise automatiquement s'ils sont présents :
- **Vault** (cadeau de victoire en monnaie économique) — ✓ déjà dans `PLUGINS_SPIGET` (34315)
- **PlaceholderAPI** (scoreboards) — ✓ déjà dans `PLUGINS_MODRINTH`
- **DecentHolograms** (leaderboards TOP wins) — ✓ déjà dans `PLUGINS_MODRINTH`

Aucune config supplémentaire nécessaire — le plugin les détecte au chargement.

### Étape 5 — récompenses (optionnel)

Fichier : `/data/plugins/TNTRun/arenas.yml` section par arène :

```yaml
classico:
  rewards:
    enabled: true
    # Commandes exécutées à la victoire (console, %player% = vainqueur)
    commands:
      - "eco give %player% 50"                    # Vault : 50 coins
      - "broadcast &e%player% a gagné TntRun!"
    # Items distribués au vainqueur
    items:
      - "iron_ingot:5"
      - "cooked_beef:16"
```

### Étape 6 — permission (via LuckPerms)

Par défaut, rejoindre une arène = `tntrun.arena.classico`. Donne le à tout le monde :

```
make cmd ARGS="lp group default permission set tntrun.arena.* true"
make cmd ARGS="lp group default permission set tntrun.join true"
make cmd ARGS="lp group default permission set tntrun.leave true"
```

### Étape 7 — jouer

```
# En jeu (n'importe quel joueur) :
/tr join classico            # rejoint l'arène
/tr leave                    # quitte
/tr list                     # arènes disponibles
/tr stats                    # stats perso (wins/deaths)
/tr top                      # leaderboard
```

---

## SkyWars — setup & configuration des 11 maps

**Plugin** : SkyWarsReloaded par lukasvdgaag (SpigotMC 69436).
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto.

**Maps disponibles** (cf. [`assets/schematics/README.md`](../assets/schematics/README.md)) :
```
skywars-classico, skywars-dune, skywars-frozen, skywars-jungle, skywars-tree,
skywars-ballon, skywars-ballon-oringin, skywars-bones, skywars-nethugly,
skywars-duels, Sky_Duel
```
→ **11 maps** au total.

### Étape 1 — déployer et vérifier

```bash
make re
make cmd ARGS=plugins          # → "SkyWarsReloaded" en vert
```

Logs attendus :
```
[SkyWarsReloaded] Enabling SkyWarsReloaded v4.X.Y
[SkyWarsReloaded] Successfully hooked into Vault
[SkyWarsReloaded] Successfully hooked into PlaceholderAPI
[SkyWarsReloaded] Loaded 0 arenas
```

### Étape 2 — créer un monde par arène (Multiverse, autoLoad=false)

Une map par arène, toutes préfixées `sw-` pour tri propre dans `/mv list`. Le `autoLoad false` fait que la map n'est chargée **que** quand un joueur y TP → économie RAM critique avec 11 arènes.

```bash
# Boucle shell côté local (via make cmd, chaque cmd passe par RCON)
for map in classico dune frozen jungle tree ballon ballon-oringin bones nethugly duels sky-duel; do
    make cmd ARGS="mv create sw-$map normal -t FLAT -g FLAT -s 0"
    make cmd ARGS="mv modify sw-$map set gamemode adventure"
    make cmd ARGS="mv modify sw-$map set pvp true"
    make cmd ARGS="mv modify sw-$map set difficulty normal"
    make cmd ARGS="mv modify sw-$map set autoLoad false"
done
```

### Étape 3 — paste chaque schematic dans sa map

Pour chaque arène (ex. `classico`) :

```
make cmd ARGS="mvtp Zoyern sw-classico"
# En jeu (client OP) :
/tp 0 100 0
//perf neighbors off                       # désactive lighting updates (paste rapide)
//schem load skywars-classico
//paste -a -o
/setworldspawn
//perf neighbors on
```

Pendant que tu pastes, **note les coords des cages** (spawns des joueurs sur chaque îlot). Typiquement 8 cages disposées autour du centre, à ±80-100 blocs. Un modèle qui marche : on note les coords d'un bord de chaque cage (où le joueur se tient) sous forme de `X Y Z`.

```
# Exemple pour sw-classico (à adapter par arène) :
Cage 1 :  80 100  80     Cage 5 :  80 100 -80
Cage 2 :   0 100 113     Cage 6 :   0 100 -113
Cage 3 : -80 100  80     Cage 7 : -80 100 -80
Cage 4 : 113 100   0     Cage 8 : -113 100   0
```

### Étape 4 — enregistrer l'arène dans SkyWarsReloaded

SWR a un mode "setup" assez guidé. Séquence pour **une** arène (`classico`) ; à répéter pour chaque map.

```
# 1) Crée l'arène
make cmd ARGS="swr create classico"

# 2) Entre en mode édition (commandes exécutées en jeu, OP)
/swr edit classico

# 3) TP dans chaque cage (1 à 8) puis :
/swr addspawn                    # enregistre la position du cursor comme spawn

# 4) TP à l'endroit du spectator spawn (au-dessus de la map, vue d'ensemble)
/swr setspectatespawn

# 5) TP au centre du lobby de pré-partie (scoreboard, compte à rebours)
/swr setlobby

# 6) Définit les coins de la map (pour reset auto — SWR copie l'état
#    initial et le restaure entre parties)
/swr setpos1           # coin -X -Y -Z
/swr setpos2           # coin +X +Y +Z

# 7) Sauvegarde + valide
/swr save
/swr enable classico
```

### Étape 5 — loot tables (chest loot)

Fichier principal : `/data/plugins/SkyWarsReloaded/chest/basic.yml` (livré par défaut, jouable tel quel). Pour customiser :

```yaml
# basic.yml — extrait
items:
  stone_sword:
    chance: 40          # % d'apparition par slot
    min: 1
    max: 1
  iron_sword:
    chance: 15
    min: 1
    max: 1
  bow:
    chance: 20
    min: 1
    max: 1
  arrow:
    chance: 60
    min: 4
    max: 16
  golden_apple:
    chance: 25
    min: 1
    max: 2
  oak_planks:
    chance: 80
    min: 8
    max: 32
```

Après modif, recharge avec :
```
make cmd ARGS="swr reload"
```

**Astuce** : SWR supporte **plusieurs loot tables** (`basic.yml`, `op.yml`, `normal.yml`). Tu peux assigner un type différent par arène dans `arenas.yml` (ex : les maps "duels" avec loot OP).

### Étape 6 — kits (facultatif)

SWR n'a pas de système de kit intégré — par défaut, les joueurs arrivent cage vide et la récup se fait via chests. Si tu veux des kits :

**Option A (simple)** : kits EssentialsX distribués au début de partie via command scheduler (dans `arenas.yml`, section `onstart`).

**Option B (propre)** : installer `CombatLogX` + `AdvancedKits` (tous deux Spiget, libres). À ajouter à `PLUGINS_SPIGET` plus tard si besoin.

### Étape 7 — permissions

```
make cmd ARGS="lp group default permission set swr.join true"
make cmd ARGS="lp group default permission set swr.leave true"
make cmd ARGS="lp group default permission set swr.play true"
```

### Étape 8 — activer toutes les arènes (une fois les 11 setup)

```bash
for map in classico dune frozen jungle tree ballon ballon-oringin bones nethugly duels sky-duel; do
    make cmd ARGS="swr enable $map"
done
```

### Étape 9 — jouer

```
# En jeu :
/swr join classico          # rejoint une arène précise
/swr join                   # rejoint automatiquement une arène dispo (matchmaking)
/swr leave                  # quitte
/swr list                   # arènes + nb joueurs
/swr stats                  # stats perso
/swr top                    # leaderboard
```

---

## Intégration lobby (warps + NPC)

Dans le monde `hub`, on pose **un portail visuel par mini-game** qui TP directement dans le lobby du plugin correspondant.

### Étape 1 — créer les warps EssentialsX

```
# TP à l'emplacement souhaité dans le hub, puis :
/warp set tntrun            # portail TntRun
/warp set skywars           # portail SkyWars
```

### Étape 2 — pressure plate + command block (rapide, moche)

```
# Sous le portail :
/fill ~ ~-1 ~ ~ ~-1 ~ light_weighted_pressure_plate
/setblock ~ ~-2 ~ command_block{Command:"execute as @p run tr join classico",auto:1b}
```

Remplace la commande par `swr join` pour SkyWars.

### Étape 3 — holograms DecentHolograms (propre)

Un holo flottant au-dessus du portail, avec placeholders SWR/TR :

```
/dh create sw-portal
/dh addline sw-portal &6&l⚔ SKYWARS ⚔
/dh addline sw-portal &7%swr_arena_count% arènes actives
/dh addline sw-portal &e%swr_total_players% joueurs en ligne
/dh addline sw-portal &aClic droit pour rejoindre

/dh create tr-portal
/dh addline tr-portal &c&l☄ TNTRUN ☄
/dh addline tr-portal &7Dernier debout gagne
/dh addline tr-portal &aClic droit pour rejoindre
```

### Étape 4 — NPC (optionnel, nécessite Citizens ou équivalent)

Citizens n'est pas dans notre stack. Alternative : **armor stands taggés** + un mini-plugin custom qui écoute `PlayerInteractAtEntityEvent` et exécute le warp. ~100 lignes Java, à déposer dans `plugins/manual/` plus tard. Pour l'instant, l'option pressure plate + holo suffit.

---

## Checklist de test

Avant de tester avec un ami :

```
[ ] make cmd ARGS=plugins affiche TNTRun ET SkyWarsReloaded en vert
[ ] make cmd ARGS="lp group default permission info"
        → inclut tntrun.* et swr.*
[ ] /mv list montre toutes les sw-* + tntrun_arena
[ ] /tr list  → classico (ou autre) apparaît "enabled"
[ ] /swr list → au moins 1 arène "enabled"
[ ] Tu peux /tr join classico depuis le hub
[ ] Tu peux /swr join classico depuis le hub
[ ] Les chests des îles SkyWars ont du loot (entre dans une cage, ouvre le chest)
[ ] En tombant dans le vide → tu meurs et respawn dans le lobby du mini-game
[ ] En fin de partie, TP automatique au hub
[ ] Les holograms DecentHolograms affichent les bons compteurs
```

---

## Troubleshooting

### Le plugin n'apparaît pas dans `make cmd ARGS=plugins` après `make re`

**Cause la plus fréquente** : l'API Spiget a rate-limit, ou le plugin a été dépublié.

```bash
# Voir ce que itzg a tenté de télécharger
make logs-main | grep -iE "spiget|downloading|skywars|tntrun"

# Si "Failed to download resource 69436"...
# Option 1 : retry au prochain boot
make restart-main

# Option 2 : télécharger manuellement et basculer en voie plugins/manual/
#   → download jar depuis SpigotMC (web)
#   → dépose dans plugins/manual/
#   → retire 69436 de PLUGINS_SPIGET (.env + k8s/main/deployment.yaml)
#   → make plugins-sync
```

### SkyWarsReloaded : erreur "unsupported server version" au chargement

Cause : le jar a été buildé pour une version trop récente (ou trop ancienne) de Paper. Vérifier :

```bash
# Dans le pod :
make ssh
kubectl -n mineshark exec deploy/mc-main -c minecraft -- cat /data/plugins/SkyWarsReloaded/plugin.yml 2>/dev/null | grep api-version
```

Doit être ≤ 1.21. Si non, pin une version précédente via `plugins/manual/` (télécharge une release GitHub plus ancienne).

### TntRun_reloaded : erreur "could not load arena classico"

Cause : `arenas.yml` corrompu ou bug de save en mode setup. Reset :

```bash
kubectl -n mineshark exec deploy/mc-main -c minecraft -- rm /data/plugins/TNTRun/arenas.yml
make restart-main
# Puis refais le setup /trsetup depuis zéro
```

### `make plugins-sync` : "Permission denied" sur le VPS

Cause : le dossier `/var/lib/mineshark/manual-plugins/` a été créé par k3s (root), l'user SSH ne peut pas écrire dedans. Fix une fois pour toutes :

```bash
make ssh
sudo mkdir -p /var/lib/mineshark/manual-plugins
sudo chown -R mineshark:mineshark /var/lib/mineshark/manual-plugins
sudo chmod 755 /var/lib/mineshark/manual-plugins
exit
# Puis réessaie :
make plugins-sync
```

### Les joueurs ne peuvent pas rejoindre : "vous n'avez pas la permission"

LuckPerms default group n'a pas la permission. Redonne-la :

```
make cmd ARGS="lp group default permission set tntrun.join true"
make cmd ARGS="lp group default permission set swr.join true"
```

### Lag sévère quand 3+ arènes SkyWars tournent en même temps

Normal avec `autoLoad=true` sur toutes les maps. Vérifie :

```
make cmd ARGS="mv list"
# Les arènes "inactives" doivent être UNLOADED (●).
# Si elles sont LOADED (○), c'est que autoLoad=true → fix :
make cmd ARGS="mv modify sw-classico set autoLoad false"
# ... pour chaque arène
```

---

## Références

- Paper 1.21.8 JavaDoc : <https://jd.papermc.io/paper/1.21.8/>
- TntRun_reloaded (Spigot) : <https://www.spigotmc.org/resources/tntrun_reloaded-tntrun-for-1-13-1-21-11.53359/>
- SkyWarsReloaded (lukasvdgaag) : <https://github.com/lukasvdgaag/SkyWarsReloaded> · <https://www.spigotmc.org/resources/69436/>
- itzg/minecraft-server docs (env vars plugin auto-install) : <https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/>
- API Spiget : <https://spiget.org/>
- WorldGuard flags : <https://worldguard.enginehub.org/en/latest/regions/flags/>
- Schematic inventory : [`assets/schematics/README.md`](../assets/schematics/README.md)
- Workflow jars manuels : [`plugins/manual/README.md`](../plugins/manual/README.md)
