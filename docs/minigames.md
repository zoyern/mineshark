# Mini-games MineShark — catalogue complet

Guide **end-to-end** pour installer, configurer et faire tourner tous les mini-jeux du serveur principal MineShark (Paper 1.21.8). Tout est auto-installé au boot du pod — pas de manipulation manuelle sur le VPS. La référence pour la liste des plugins et leurs versions est [`docs/plugins.md`](plugins.md).

> **Stack mini-jeux (avril 2026)** — tous activement maintenus pour 1.21.x :
>
> | Mini-jeu | Plugin | Spiget ID | Joueurs |
> |---|---|---|---|
> | TntRun | TntRun_reloaded (TheDev12) | `53359` | 2-12 |
> | SkyWars | SkyWarsReloaded (fork **lukasvdgaag** FREE) | `69436` | 2-12 par arène |
> | BedWars | ScreamingBedWars (ScreamingSandals) | `63714` | 2-16 par équipe |
> | Spleef / Splegg | Spleef_reloaded (steve4744) | `118673` | 2-8 |
> | Murder Mystery | MurderMystery (Plugily-Projects) | `66614` | 4-12 |
> | One In The Chamber | OITC (Despical) | `81185` | 2-8 |
> | OneBlock (Skyblock) | BentoBox + AOneBlock | `73261` + jar manuel | solo ou co-op |
>
> Toutes les sources Spiget s'auto-installent via l'API Spiget. L'addon AOneBlock (OneBlock) est un jar manuel (`plugins/manual/bentobox-addons/`, voir section dédiée).

## Sommaire

- [Ajout d'un plugin mini-game : les 4 voies](#ajout-dun-plugin-mini-game--les-4-voies)
- [Workflow complet côté VPS](#workflow-complet-côté-vps)
- [TntRun — setup & configuration](#tntrun--setup--configuration)
- [SkyWars — setup & configuration des 11 maps](#skywars--setup--configuration-des-11-maps)
- [ScreamingBedWars — setup 2-4 équipes](#screamingbedwars--setup-2-4-équipes)
- [Spleef_reloaded — setup arène](#spleef_reloaded--setup-arène)
- [MurderMystery — setup arène](#murdermystery--setup-arène)
- [OITC (One In The Chamber) — setup arène](#oitc-one-in-the-chamber--setup-arène)
- [OneBlock (AOneBlock + BentoBox) — setup skyblock moderne](#oneblock-aoneblock--bentobox--setup-skyblock-moderne)
- [Intégration lobby — Advanced Portals (hub → hub-minigames)](#intégration-lobby--advanced-portals-hub--hub-minigames)
- [Checklist de test](#checklist-de-test)
- [Troubleshooting](#troubleshooting)
- [Convention schematics (.schem > .schematic)](#convention-schematics-schem--schematic)
- [Références](#références)

---

## Ajout d'un plugin mini-game : les 4 voies

Selon où se trouve le plugin, on a **quatre** mécaniques d'installation automatique — toutes gérées par l'image `itzg/minecraft-server`. Aucune ne nécessite de toucher au VPS à la main (sauf la voie "jar manuel" qui passe par `make plugins-sync`).

| Source | Variable | Fichier | Exemple |
|---|---|---|---|
| **Modrinth** (modrinth.com) | `MODRINTH_PROJECTS` | `.env` → `PLUGINS_MODRINTH` | `luckperms`, `chunky` |
| **SpigotMC** (spigotmc.org, free) | `SPIGET_RESOURCES` | `.env` → `PLUGINS_SPIGET` | `53359` (TntRun), `69436` (SkyWars) |
| **URL directe** (GitHub, CDN) | `PLUGINS` | `k8s/main/deployment.yaml` | EssentialsX, ViaVersion |
| **Jar à la main** (payant, disparu, custom, addon BentoBox) | `plugins/manual/` ou `plugins/manual/bentobox-addons/` | le dossier du repo | voir [README.md](../plugins/manual/README.md) |

**Règle de choix** : toujours préférer Modrinth > Spiget > URL > manuel. Plus haut dans cette liste = moins de friction et mises à jour gérées par itzg.

**Tous les mini-jeux listés dans le tableau d'intro sont déjà ajoutés** au projet — rien à faire pour l'installation, il faut juste les configurer in-game.

> Pour ajouter un nouveau plugin, la source de vérité unique est [`docs/plugins.md`](plugins.md) (sections 3 et 7). **Jamais** ajouter un plugin ici sans l'ajouter là.

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

### Étape 2 — modèle **V3 lukasvdgaag** : 1 monde Multiverse = 1 map

Contrairement à l'ancien SkyWarsReloaded (Dabo Ross) qui copiait un schematic dans un monde "arena" temporaire, la **v3 de lukasvdgaag** utilise **Multiverse directement** : chaque map est **son propre monde Multiverse** et SWR gère le reset via backup/restore du monde. Avantages :

- Pas de duplication de map à chaque game.
- Le monde est persistant → tu peux y retourner pour le modifier entre deux parties.
- Reset automatique entre games (option).
- `autoLoad=false` → la map n'est chargée que quand quelqu'un y joue → économie RAM massive.

**Choix du générateur void** : on utilise **VoidWorldGenerator** (Spiget 113931 par HydrolienF, déjà dans `PLUGINS_SPIGET`), un plugin dédié qui expose un générateur nommé `VoidWorldGenerator` à Multiverse. On l'invoque via `-g VoidWorldGenerator` → monde **100 % vide**, pas de bedrock, pas de grass, rien. Juste de l'air de Y=-64 à Y=320.

> **Pourquoi pas le générateur bundlé SkyWarsReloaded (`-g SkyWarsReloaded`) ?** Parce qu'on veut garder MineShark **stack-propre** : un seul générateur void réutilisable par **tous** les mini-jeux (SkyWars, BedWars dérivés, Spleef, etc.) plutôt qu'un par plugin. Si un jour on retire SkyWarsReloaded, les mondes ne deviennent pas orphelins (erreur `Unknown generator` au boot).
>
> ⚠️ **Piège à éviter** : `-t FLAT -g FLAT` crée un monde **superflat** (bedrock+dirt+grass) — c'est **PAS** un void, tu aurais une plaine sous les îles. Ne l'utilise **jamais** pour SkyWars.

### Étape 3 — commencer **par une seule map** : Bones (validation de la chaîne)

Avant de batcher les 11 maps, on fait **bones** seule de A à Z pour valider que la pipeline fonctionne. Une fois bones jouable, tu dupliques pour les autres.

**3.1 — Créer le monde void**

```bash
# Monde void via VoidWorldGenerator (Spiget 113931)
make cmd ARGS="mv create sw-bones normal -g VoidWorldGenerator"

# Config de l'arène (PVP on, pas d'auto-load pour économie RAM)
make cmd ARGS="mv modify sw-bones set pvp true"
make cmd ARGS="mv modify sw-bones set difficulty normal"
make cmd ARGS="mv modify sw-bones set autoLoad false"
make cmd ARGS="mv modify sw-bones set keepSpawnInMemory false"

# Gamemode : survival (les joueurs doivent pouvoir casser les blocs des
# îles + ouvrir les chests). SWR forcera le gamemode "survival" au start
# de chaque partie de toute façon, donc peu importe ici — mais NE PAS
# mettre adventure (bloquerait WorldEdit quand tu pastes le schematic).
make cmd ARGS="mv modify sw-bones set gamemode survival"
```

Vérification que le monde est bien void :

```bash
make cmd ARGS="mvtp Zoyern sw-bones"
# En jeu : tu devrais flotter dans le vide, rien à l'horizon.
# Si tu vois une plaine → VoidWorldGenerator n'est pas chargé (voir Troubleshooting).
```

**3.2 — Paster le schematic bones**

En jeu (client OP) :

```
/tp 0 100 0
/gamemode creative
//perf neighbors off          # désactive light updates (paste beaucoup plus rapide)
//schem load skywars-bones
//paste -a -o                 # -a = ignore air, -o = origin at player
/setworldspawn
//perf neighbors on
/gamemode survival
```

**3.3 — Noter les coords des spawns (cages)**

Chaque île a une cage en verre où spawn un joueur. Vole à chaque cage, **pose-toi sur le bloc où le joueur doit apparaître** (centre de la cage, sur le sol), et note tes coords avec `/tp` ou l'overlay F3.

Format à noter (exemple, à adapter à ton schematic bones) :

```
Cage 1 :   X  Y  Z
Cage 2 :   X  Y  Z
...
```

Pour le schematic bones il y a typiquement **8 îles** disposées en octogone. Les coords sont souvent à ±80 à 100 blocs du centre, à Y=100.

**3.4 — Enregistrer l'arène dans SkyWarsReloaded**

SWR v3 a un mode setup interactif. En jeu :

```
# Crée l'arène "bones" (le nom interne SWR, pas forcément le nom de monde)
/swr create bones sw-bones

# Entre en mode édition
/swr edit bones

# Pour chaque cage (1 à 8) :
#   1. TP à la position notée en 3.3
#   2. Exécute :
/swr addspawn

# Position où les morts / spectateurs TP :
/swr setspectatespawn

# Coins de la zone à reset entre parties (la bounding box de toute la map) :
#   1. Vole au coin bas-ouest-sud (-X, -Y, -Z)
/swr setpos1
#   2. Vole au coin haut-est-nord (+X, +Y, +Z)
/swr setpos2

# Sauvegarde la config
/swr save

# Active l'arène (joueurs peuvent la rejoindre)
/swr enable bones
```

**3.5 — Tester**

```
/swr join bones           # tu devrais être TP dans une cage
# Attends 1 autre joueur (ou lance seul avec /swr forcestart bones en OP)
```

**Si ça marche → passe au 3.6. Si ça plante → voir [Troubleshooting](#troubleshooting).**

### Étape 4 — dupliquer pour les 10 autres maps

Une fois bones validée, tu automatises le reste. Mais attention : **les coords des cages ne sont pas identiques d'une map à l'autre** (chaque schematic est différent). Les étapes automatisables sont la création du monde void + le paste. Le `/swr addspawn` reste manuel (une fois par cage).

**4.1 — Boucle shell pour créer les 10 mondes void restants**

```bash
# Mondes (hors bones, déjà faite)
for map in classico dune frozen jungle tree ballon ballon-oringin nethugly duels sky-duel; do
    make cmd ARGS="mv create sw-$map normal -g VoidWorldGenerator"
    make cmd ARGS="mv modify sw-$map set pvp true"
    make cmd ARGS="mv modify sw-$map set difficulty normal"
    make cmd ARGS="mv modify sw-$map set autoLoad false"
    make cmd ARGS="mv modify sw-$map set keepSpawnInMemory false"
    make cmd ARGS="mv modify sw-$map set gamemode survival"
done
```

**4.2 — Pour chaque map, paster son schematic + setup SWR**

Répète les étapes 3.2 à 3.5 pour chaque nom de map. Le schematic correspondant est `skywars-<map>` (ex. `skywars-classico`, `skywars-dune`...).

**Tableau de suivi** — coche au fur et à mesure :

```
[x] bones          (validée)
[ ] classico       ( /__ cages enregistrées)
[ ] dune           ( /__ cages)
[ ] frozen         ( /__ cages)
[ ] jungle         ( /__ cages)
[ ] tree           ( /__ cages)
[ ] ballon         ( /__ cages)
[ ] ballon-oringin ( /__ cages)
[ ] nethugly       ( /__ cages)
[ ] duels          ( /__ cages)
[ ] sky-duel       ( /__ cages)
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

## ScreamingBedWars — setup 2-4 équipes

**Plugin** : ScreamingBedWars (SpigotMC 63714), maintenu par ScreamingSandals.
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto.

### Étape 1 — déployer et vérifier

```bash
make re
make cmd ARGS=plugins          # → "ScreamingBedWars" en vert
```

Logs attendus :
```
[ScreamingBedWars] Enabling ScreamingBedWars vX.Y
[ScreamingBedWars] Loaded 0 games
```

### Étape 2 — créer le monde void de la map

```bash
# 1 monde Multiverse = 1 carte BedWars (convention MineShark)
make cmd ARGS="mv create bw-classico normal -g VoidWorldGenerator"
make cmd ARGS="mv modify bw-classico set pvp true"
make cmd ARGS="mv modify bw-classico set difficulty normal"
make cmd ARGS="mv modify bw-classico set autoLoad false"
make cmd ARGS="mv modify bw-classico set gamemode survival"
```

### Étape 3 — paster la map depuis `assets/schematics/`

En jeu (client OP) :

```
/mvtp bw-classico
/tp 0 100 0
/gamemode creative
//schem load bedwars-classico
//paste -a -o
/setworldspawn
```

La map typique BedWars a : **1 île centrale** (diamants/émeraudes), **2-4 îles d'équipe** (chacune avec 1 lit + 1 spawner de fer/or + 1 coffre d'achat), et **des forges** (generators) qui droppent les ressources au sol.

### Étape 4 — créer l'arène BedWars

ScreamingBedWars expose la commande `/bw admin` pour le setup complet. En jeu :

```
# Créer l'arène
/bw admin classico add

# Entrer en mode édition
/bw admin classico edit

# Définir les 2 coins de la bounding box (reset zone) :
#   1. Vole au coin bas-ouest-sud (-X min, -Y min, -Z min)
/bw admin classico pos1
#   2. Vole au coin haut-est-nord (+X max, +Y max, +Z max)
/bw admin classico pos2

# Spawn du lobby (là où les joueurs attendent avant le start)
/bw admin classico lobby
# (mets-toi à la position du lobby dans un monde lobby séparé, ex. 'hub')
# Note : le lobby peut être hors du monde bw-classico — c'est l'intérêt du plugin.

# Point de spectateur (joueurs morts sans lit)
/bw admin classico spec

# Limites de joueurs et durée
/bw admin classico min 2
/bw admin classico max 16
/bw admin classico time 1800        # 30 minutes max par partie

# Ajouter des équipes (couleur = nom interne)
/bw admin classico team add red RED 4         # nom=red, couleur=RED, taille max=4
/bw admin classico team add blue BLUE 4
/bw admin classico team add green GREEN 4     # optionnel, si map 3 équipes
/bw admin classico team add yellow YELLOW 4   # optionnel, si map 4 équipes

# Pour chaque équipe, définir :
#   - Le spawn (bloc où le joueur apparaît)
/bw admin classico team spawn red
#   - La position du lit (bloc du lit)
/bw admin classico team bed red
#   - Le village marchand (villager shops)
/bw admin classico store add red

# Spawners de ressources (fer/or/diamant/émeraude) :
#   - Va sur le bloc du spawner, puis :
/bw admin classico spawner add iron 1         # tier 1
/bw admin classico spawner add gold 1
/bw admin classico spawner add diamond 2      # spawners diamant au centre (tier 2)
/bw admin classico spawner add emerald 3      # émeraudes tier 3

# Sauvegarder
/bw admin classico save
```

### Étape 5 — tester

```
/bw join classico          # rejoint le lobby
/bw leave                  # quitte
/bw list                   # liste des arènes
/bw stats                  # stats perso
```

### Étape 6 — permissions

```
make cmd ARGS="lp group default permission set bw.join true"
make cmd ARGS="lp group default permission set bw.leave true"
make cmd ARGS="lp group default permission set bw.stats true"
```

Les permissions admin (`bw.admin.*`) sont réservées aux OP.

### Étape 7 — shop items (facultatif)

Fichier : `/data/plugins/ScreamingBedWars/shop.yml` (livré avec un catalogue par défaut jouable). Pour customiser, édite la liste `items:` en ajoutant/retirant des entrées (sword, armor, pickaxe, potions, TNT bridge, etc.). `make cmd ARGS="bw admin reload"` pour recharger.

---

## Spleef_reloaded — setup arène

**Plugin** : Spleef_reloaded par steve4744 (SpigotMC 118673).
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto.

**Principe** : les joueurs cassent le sol sous leurs pieds (pelles), le dernier debout gagne. Mode "Splegg" = lanceurs d'œufs qui cassent les blocs à distance.

### Étape 1 — vérifier

```bash
make cmd ARGS=plugins        # → "Spleef_reloaded" en vert
```

### Étape 2 — créer la map

Plateforme carrée (typique 20×20 à 40×40) en **neige** (casse rapide à la pelle) ou **TNT décorative**, sur un monde void.

```bash
make cmd ARGS="mv create spleef_arena normal -g VoidWorldGenerator"
make cmd ARGS="mv modify spleef_arena set pvp false"
make cmd ARGS="mv modify spleef_arena set gamemode survival"
make cmd ARGS="mv modify spleef_arena set autoLoad false"
```

En jeu, construit la plateforme :

```
/mvtp spleef_arena
/tp 0 100 0
//pos1 -20 100 -20 ; //pos2 20 100 20
//set snow_block
```

### Étape 3 — créer l'arène

Spleef_reloaded expose `/spleef` (setup). En jeu :

```
/spleef create classico          # nom interne "classico"
/spleef edit classico

# Définir les 2 coins du layer qui sera reset entre parties :
/spleef floor pos1               # vole au coin bas-ouest-sud de la plateforme
/spleef floor pos2               # vole au coin haut-est-nord

# Spawn des joueurs (un point = spawn aléatoire dans un rayon ;
# ou plusieurs points = un par spot) :
/spleef addspawn                 # TP-toi sur la plateforme, une fois par spawn

# Lobby (salle d'attente, peut être dans un autre monde) :
/spleef lobby                    # TP-toi au lobby puis commande

# Point de sortie (après défaite) :
/spleef setexit                  # TP-toi dans le hub puis commande

# Paramètres
/spleef setmin 2
/spleef setmax 8
/spleef settime 300              # 5 min max

# Activer
/spleef enable classico
/spleef save
```

### Étape 4 — permissions + jeu

```
make cmd ARGS="lp group default permission set spleef.join true"
make cmd ARGS="lp group default permission set spleef.leave true"
```

```
/spleef join classico
/spleef leave
/spleef list
```

### Étape 5 — mode Splegg (facultatif)

Dans `/data/plugins/Spleef_reloaded/arenas.yml`, section de l'arène :
```yaml
classico:
  game_type: SPLEGG     # au lieu de SPLEEF (pelles)
  splegg_item: EGG
```
`make cmd ARGS="spleef reload"`. Les joueurs reçoivent un œuf-lanceur au lieu d'une pelle.

---

## MurderMystery — setup arène

**Plugin** : MurderMystery par Plugily-Projects (SpigotMC 66614).
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto.

**Principe** : 1 murderer (couteau), 1 detective (arc), les autres sont innocents. Le murderer doit tuer tout le monde sans se faire tirer dessus. Les innocents récoltent des lingots d'or qui peuvent être échangés contre un arc.

### Étape 1 — vérifier

```bash
make cmd ARGS=plugins        # → "MurderMystery" en vert
```

### Étape 2 — paster une map classique

MurderMystery se joue sur une map thématique (manoir, rue, usine…) avec des couloirs et pièces où se cacher. Paste n'importe quel schematic "building" sur un monde void ou normal.

```bash
make cmd ARGS="mv create mm_manoir normal -g VoidWorldGenerator"
make cmd ARGS="mv modify mm_manoir set autoLoad false"
make cmd ARGS="mv modify mm_manoir set gamemode survival"
make cmd ARGS="mv modify mm_manoir set pvp true"
```

En jeu :
```
/mvtp mm_manoir
//schem load murdermystery-manoir       # adapte au nom réel de ton schematic
//paste -a -o
```

### Étape 3 — créer l'arène

En jeu (OP) :

```
/mm create manoir

# Entre en mode édition
/mm edit manoir

# Lobby (hors-arène)
/mm setlobby manoir

# Points de spawn des joueurs (4 à 12 points min)
#   TP-toi à chaque spot, puis à chaque fois :
/mm addspawn manoir

# Emplacements des lingots d'or (gold spawners) :
/mm addgold manoir

# Spawn des waiting spectators / ending
/mm setendlocation manoir

# Paramètres
/mm setminplayers manoir 4
/mm setmaxplayers manoir 12
/mm settimer manoir 540          # 9 min par partie

# Activer
/mm enable manoir
```

### Étape 4 — permissions + jeu

```
make cmd ARGS="lp group default permission set murdermystery.join true"
make cmd ARGS="lp group default permission set murdermystery.leave true"
make cmd ARGS="lp group default permission set murdermystery.stats true"
```

```
/mm join manoir
/mm leave
/mm list
/mm stats
```

### Étape 5 — skins rôles (facultatif)

Fichier : `/data/plugins/MurderMystery/arenas.yml`. Tu peux définir des skins Mojang par rôle (murderer/detective/innocent) via `role_skins:` — nécessite que le serveur soit en mode online (online-mode=true) ou qu'un plugin SkinsRestorer soit présent. Pour MineShark en mode LAN/cracked, laisse par défaut.

---

## OITC (One In The Chamber) — setup arène

**Plugin** : OITC par Despical (SpigotMC 81185).
**État repo** : **déjà ajouté** à `PLUGINS_SPIGET` et `SPIGET_RESOURCES` → install auto.

**Principe** : chaque joueur commence avec 1 arc + 1 flèche + 1 épée. Un kill = 1 flèche récupérée + 1 point. Premier à N kills gagne.

### Étape 1 — vérifier

```bash
make cmd ARGS=plugins        # → "OneInTheChamber" en vert (nom interne : OITC)
```

### Étape 2 — paster une map

Arène compacte PVP avec plusieurs spawns répartis (typiquement 4-8 spawns, couloirs courts).

```bash
make cmd ARGS="mv create oitc_arena normal -g VoidWorldGenerator"
make cmd ARGS="mv modify oitc_arena set pvp true"
make cmd ARGS="mv modify oitc_arena set autoLoad false"
make cmd ARGS="mv modify oitc_arena set gamemode survival"
```

```
/mvtp oitc_arena
//schem load oitc-arena          # adapte au nom réel
//paste -a -o
```

### Étape 3 — créer l'arène

En jeu (OP), commandes Despical OITC :

```
/oitc create classico
/oitc edit classico

# Lobby (hors arène)
/oitc lobby classico

# Spawns (au moins 4, idéalement 6-8)
/oitc addspawn classico          # TP à chaque point, répète

# Point de fin (écran "GG" / retour hub)
/oitc end classico

# Paramètres
/oitc setminplayers classico 2
/oitc setmaxplayers classico 8
/oitc setscore classico 10       # premier à 10 kills gagne
/oitc settimer classico 600      # 10 min max

# Activer
/oitc enable classico
```

### Étape 4 — permissions + jeu

```
make cmd ARGS="lp group default permission set oitc.join true"
make cmd ARGS="lp group default permission set oitc.leave true"
make cmd ARGS="lp group default permission set oitc.stats true"
```

```
/oitc join classico
/oitc leave
/oitc list
```

---

## OneBlock (AOneBlock + BentoBox) — setup skyblock moderne

**Plugin** : BentoBox (SpigotMC 73261) + addon **AOneBlock** (jar manuel, `plugins/manual/bentobox-addons/`).
**État repo** : BentoBox est **déjà ajouté** à `PLUGINS_SPIGET`. AOneBlock est déposé dans `plugins/manual/bentobox-addons/` et poussé sur le VPS via `make plugins-sync`.

**Principe** : chaque joueur a son île mono-bloc qui se régénère au fur et à mesure des casses. Progression par "phases" (grass → sand → stone → …) qui débloquent de nouveaux drops.

### Étape 1 — vérifier que BentoBox et AOneBlock sont chargés

```bash
make cmd ARGS=plugins        # → "BentoBox" en vert
```

Logs attendus :
```
[BentoBox] Enabling BentoBox v2.X
[BentoBox] Loading addon AOneBlock vX.Y
[AOneBlock] Registered gamemode 'AOneBlock'
```

Si AOneBlock n'apparaît pas : `ls /data/plugins/BentoBox/addons/` doit contenir `AOneBlock-*.jar`. Si absent, c'est que `make plugins-sync` n'a pas propagé les addons. Voir [plugins/manual/README.md](../plugins/manual/README.md).

### Étape 2 — monde géré par BentoBox (automatique)

Contrairement aux autres mini-jeux, **tu ne crées PAS le monde manuellement avec Multiverse**. BentoBox crée automatiquement au premier boot :
- `aoneblock` (monde principal)
- `aoneblock_nether` (enfer si enabled dans config)
- `aoneblock_the_end` (end si enabled)

> **Normal** de voir ces 2 mondes apparaître automatiquement même si tu n'as pas créé d'île : c'est le comportement par défaut de BentoBox. Pour désactiver :
> ```yaml
> # /data/plugins/BentoBox/addons/AOneBlock/config.yml
> world:
>   nether:
>     generate: false
>   end:
>     generate: false
> ```
> Puis `make cmd ARGS="bbox reload"`. **Attention** : tu ne peux désactiver le nether/end qu'**avant** qu'un joueur crée sa première île. Après, les mondes sont persistants.

### Étape 3 — config importante (`AOneBlock/config.yml`)

```yaml
world:
  friendly-name: "OneBlock"
  island-start-x: 0
  island-start-z: 0
  island-distance: 400          # distance entre îles joueurs (évite conflits)
  max-islands: 0                # 0 = illimité
  default-game-mode: SURVIVAL
  nether:
    generate: true              # laisse à true ou false selon ta préférence
    islands: true               # îles nether par joueur
  end:
    generate: true
    islands: true

island:
  max-team-size: 4              # max 4 joueurs par île (co-op)
  max-homes: 5
```

Après modif : `make cmd ARGS="bbox reload AOneBlock"`.

### Étape 4 — permissions

```
make cmd ARGS="lp group default permission set aoneblock.island.create true"
make cmd ARGS="lp group default permission set aoneblock.island.home true"
make cmd ARGS="lp group default permission set aoneblock.island.invite true"
make cmd ARGS="lp group default permission set aoneblock.island.team true"
```

### Étape 5 — jeu (commandes joueurs)

```
/aob create              # crée ton île (ou '/is' via alias BentoBox)
/aob home                # TP à ta maison
/aob invite <pseudo>     # invite en co-op
/aob level               # calcule ton score (basé sur les blocs posés)
/aob top                 # leaderboard

# Commandes admin
/aob admin delete <pseudo>    # reset l'île d'un joueur
/aob admin info <pseudo>
```

### Étape 6 — phases custom (facultatif, avancé)

Les phases sont définies dans `/data/plugins/BentoBox/addons/AOneBlock/phases/`. Chaque fichier `.yml` décrit 100 blocs de progression (pondération des drops). AOneBlock livre une 20aine de phases par défaut (Plains → Underground → Snow → Desert → etc.), le jeu est très jouable tel quel.

---

## Intégration lobby — Advanced Portals (hub → hub-minigames)

**Plugin** : Advanced Portals (par sekwah41, disponible sur Modrinth + Spiget). **Déjà ajouté** à `PLUGINS_MODRINTH` → install auto.

**Pourquoi Advanced Portals plutôt que pressure-plate + command-block ?**

- Les portails sont **des régions** (pas des blocs uniques) → effet visuel avec particules, "seuil" de téléportation propre (pas besoin de sauter sur une dalle).
- Config persistée dans `/data/plugins/AdvancedPortals/` → backup/restore via `make backup` capture tout.
- Commande de destination → warp EssentialsX → commande plugin. Modifiable à la volée sans casser/reposer de command-blocks.
- Activation conditionnelle : exige une permission, un item, un gamemode, etc.

### Étape 1 — vérifier le plugin

```bash
make cmd ARGS=plugins        # → "AdvancedPortals" en vert
```

### Étape 2 — créer les destinations (commandes à exécuter)

Les "destinations" sont les commandes que chaque portail lancera quand un joueur passera à travers. On les nomme selon le mini-jeu :

```
# En jeu, OP :
/portal destination create tntrun-lobby command "tr join classico"
/portal destination create skywars-lobby command "swr join"
/portal destination create bedwars-lobby command "bw join classico"
/portal destination create spleef-lobby command "spleef join classico"
/portal destination create murder-lobby command "mm join manoir"
/portal destination create oitc-lobby command "oitc join classico"
/portal destination create oneblock-lobby command "aob create"
```

### Étape 3 — créer chaque portail (sélection visuelle)

Tu passes dans le mode éditeur du plugin (t'équipes l'outil selector) puis sélectionnes une zone 3D. Le plugin enregistre la bounding box comme "portail".

```
# En jeu (OP), dans le hub :
/portal wand                      # te donne l'outil sélecteur (blaze_rod par défaut)

# 1) Clic-gauche le coin bas-ouest-sud du portail (ex. sous la dalle)
# 2) Clic-droit le coin haut-est-nord (ex. 3 blocs au-dessus)
# 3) Enregistre le portail (exemple pour SkyWars) :
/portal create skywars skywars-lobby
#                 ^       ^
#                 nom     destination créée à l'étape 2
```

Répète pour chaque mini-jeu (`tntrun`, `bedwars`, `spleef`, `murder`, `oitc`, `oneblock`).

### Étape 4 — effets visuels (facultatif)

```
# Particules (portal_particle par défaut) :
/portal arg skywars particle PORTAL
/portal arg skywars sound ENTITY_ENDERMAN_TELEPORT
# Message de traversée :
/portal arg skywars message "&6[SkyWars]&e Matchmaking..."
```

### Étape 5 — holograms au-dessus (DecentHolograms)

Un holo flottant au-dessus de chaque portail, avec placeholders PlaceholderAPI :

```
/dh create sw-portal
/dh addline sw-portal "&6&l⚔ SKYWARS ⚔"
/dh addline sw-portal "&7%swr_arena_count% arènes actives"
/dh addline sw-portal "&e%swr_total_players% joueurs en ligne"
/dh addline sw-portal "&aTraverse le portail pour jouer !"

/dh create tr-portal
/dh addline tr-portal "&c&l☄ TNTRUN ☄"
/dh addline tr-portal "&7Dernier debout gagne"
/dh addline tr-portal "&aTraverse le portail pour jouer !"
```

Duplique pour chaque mini-jeu (placeholder approprié : `%bedwars_*%`, `%mm_*%`, etc.).

### Étape 6 — permission de traversée (tous les joueurs par défaut)

Advanced Portals met par défaut `advancedportals.use.*` à `true` (bypass si tu n'as aucune règle). Si tu veux restreindre :

```
make cmd ARGS="lp group default permission set advancedportals.use.skywars true"
# etc.
```

### Étape 7 — liste/édition

```
/portal list                      # liste tous les portails du hub
/portal edit skywars              # entre en mode édition
/portal destination list          # liste des destinations
/portal remove skywars            # supprime un portail (la zone reste vide)
```

> **Config brute** : `/data/plugins/AdvancedPortals/portals.yml` et `.../destinations.yml`. Tu peux les éditer à la main (plus rapide que commande par commande pour 7 portails), puis `/portal reload`.

---

## Checklist de test

Avant de tester avec un ami :

```
[ ] make cmd ARGS=plugins affiche tous les plugins mini-jeux en vert :
       TNTRun, SkyWarsReloaded, ScreamingBedWars, Spleef_reloaded,
       MurderMystery, OITC (OneInTheChamber), BentoBox, AdvancedPortals,
       VoidWorldGenerator
[ ] make cmd ARGS="lp group default permission info"
        → inclut tntrun.*, swr.*, bw.*, spleef.*, murdermystery.*, oitc.*,
          aoneblock.island.*
[ ] /mv list montre toutes les sw-*, bw-*, tntrun_arena, spleef_arena,
        mm_manoir, oitc_arena, aoneblock (+ aoneblock_nether / _the_end)
[ ] /tr list         → au moins 1 arène "enabled"
[ ] /swr list        → au moins 1 arène "enabled"
[ ] /bw list         → au moins 1 arène "enabled"
[ ] /spleef list     → au moins 1 arène "enabled"
[ ] /mm list         → au moins 1 arène "enabled"
[ ] /oitc list       → au moins 1 arène "enabled"
[ ] /portal list     → au moins 7 portails dans le hub (un par mini-jeu)
[ ] Tu peux /tr join <map> / /swr join / /bw join … depuis le hub
[ ] Tu peux traverser chaque portail Advanced Portals → TP automatique au lobby du mini-jeu
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

### `mv create sw-bones -g VoidWorldGenerator` → "Unknown generator"

Cause : VoidWorldGenerator n'a pas fini de charger avant que tu tapes la commande, **OU** le plugin n'a pas pu être téléchargé depuis Spiget (rate-limit, jar cache obsolète).

**Fix 1 — attendre + vérifier** : le premier boot post-install prend 60-90s. Tape :
```
make cmd ARGS="plugins"
```
Et vérifie que `VoidWorldGenerator` est en **vert** (chargé). Si absent ou en rouge :
```
make logs-main | grep -iE "void|113931|HydrolienF"
```
Si `Failed to download resource 113931`, force un re-download :
```
make update-plugins
```
(supprime les jars + les dotfiles `.113931-version.json` du cache meta Spiget → itzg retélécharge tout au redémarrage).

**Fix 2 — fallback sur le générateur bundlé SkyWarsReloaded** : SkyWarsReloaded v3 expose aussi son propre générateur `SkyWarsReloaded`. Tu peux l'utiliser en dépannage (mais on préfère `VoidWorldGenerator` pour la portabilité cross-minigames — cf. Étape 2) :

```bash
make cmd ARGS="mv create sw-bones normal -g SkyWarsReloaded"
```

Fonctionnellement identique — monde 100 % vide. À n'utiliser que si VoidWorldGenerator refuse obstinément de charger.

> **Note pour les lecteurs qui ont un vieux tuto sous les yeux** : l'ID Spiget `27934` n'est **PAS** un plugin void generator. C'est "Simple Spawners" (plugin de mob spawners pour Minecraft 1.7-1.12, plus maintenu). Ne l'ajoute **jamais** à `PLUGINS_SPIGET` — il ne se chargera même pas sur Paper 1.21.

### Je vois des plaines sous mes îles SkyWars

Cause : tu as utilisé `-t FLAT -g FLAT` (ou rien, qui tombe sur le générateur normal = plaines biome aléatoire). Le monde n'est **pas** void.

**Fix** : supprime le monde et recrée avec le bon générateur :

```bash
# 1) Arrête le monde côté Multiverse
make cmd ARGS="mv delete sw-bones"
# Multiverse demande confirmation : retape la commande dans les 5s
make cmd ARGS="mv delete sw-bones"

# 2) Recrée avec -g VoidWorldGenerator
make cmd ARGS="mv create sw-bones normal -g VoidWorldGenerator"
# Puis refais les mv modify + le paste schematic
```

### `/swr addspawn` me dit "arena not in edit mode"

Cause : tu as oublié de faire `/swr edit bones` avant. Il faut être **dans le monde** `sw-bones` **ET** en mode édition (`/swr edit bones`) pour que les commandes de setup s'appliquent à cette arène.

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

## Convention schematics (.schem > .schematic)

Tous les schematics MineShark sont en format **`.schem`** (Sponge schematic, nouveau format WorldEdit 7+), **pas** l'ancien `.schematic` (MCEdit legacy).

### Pourquoi `.schem` et pas `.schematic` ?

| Critère | `.schematic` (legacy) | `.schem` (Sponge 3) |
|---|---|---|
| Year | 2011 (MCEdit) | 2017 (WorldEdit) |
| Block IDs | numériques (1, 3, 35…) | namespaced (`minecraft:stone`) |
| Block states | non supporté | oui (orientation portes, waterlogged…) |
| Minecraft 1.13+ | cassé (flattening) | natif |
| Biomes, entités | non | oui |
| WorldEdit moderne | read-only, warn | lecture + écriture |

À partir de MC 1.13, le "flattening" a supprimé les IDs numériques → `.schematic` devient un format dégradé qui perd les informations de blocs complexes (directions d'escaliers, slab half, etc.). Pour tout ce qui est posé/construit sur **Paper 1.21.x**, utilise **toujours** `.schem`.

### Emplacement dans le repo

```
assets/schematics/
├── hub.schem                     # lobby central
├── tntrun-classico.schem
├── skywars-bones.schem
├── skywars-classico.schem
├── skywars-dune.schem
├── ...
├── bedwars-classico.schem
├── murdermystery-manoir.schem
└── oitc-arena.schem
```

→ Au boot du pod `mc-main`, l'initContainer `copy-schematics` copie tout le dossier dans `/data/plugins/WorldEdit/schematics/`. Les fichiers y sont accessibles via `//schem load <nom-sans-extension>`.

### Conversion `.schematic` → `.schem` (si tu récupères un vieux fichier)

```bash
# Depuis un client OP avec WorldEdit :
//schem load ancien-fichier.schematic
//schem save nouveau-fichier format=sponge
# WorldEdit écrit dans .../WorldEdit/schematics/nouveau-fichier.schem

# Récupère-le sur ta machine locale :
make backup                     # tarball complet du PVC mc-main
# ou directement :
kubectl -n mineshark cp mc-main-xxx:/data/plugins/WorldEdit/schematics/nouveau-fichier.schem ./nouveau-fichier.schem
```

### Nommage

Convention MineShark :

```
<minigame>-<map>.schem
```

Exemples :
- `skywars-bones.schem`, `skywars-classico.schem`, …
- `tntrun-classico.schem`
- `bedwars-4teams-fantasy.schem`
- `murdermystery-manoir.schem`

Séparateur **tiret**, pas underscore. Pas de majuscules. Pas d'espace. Le **préfixe** identifie le plugin, le suffixe identifie la map.

### Ajouter un nouveau schematic

1. Place le `.schem` dans `assets/schematics/` (via WorldEdit ou rsync local).
2. `git add assets/schematics/nouveau-fichier.schem && git commit -m "schem: add <description>"`.
3. `make deploy` → push git + rollout mc-main → l'initContainer recopie.
4. En jeu : `//schem load nouveau-fichier` puis `//paste -a -o`.

> **`.schematic` sous la main ?** Ajoute-le dans `assets/schematics/legacy/` (gitignored) → convertis-le d'abord en `.schem` via la procédure ci-dessus, puis commit seulement le `.schem`.

---

## Références

- Paper 1.21.8 JavaDoc : <https://jd.papermc.io/paper/1.21.8/>
- TntRun_reloaded (Spigot) : <https://www.spigotmc.org/resources/tntrun_reloaded-tntrun-for-1-13-1-21-11.53359/>
- SkyWarsReloaded (lukasvdgaag) : <https://github.com/lukasvdgaag/SkyWarsReloaded> · <https://www.spigotmc.org/resources/69436/>
- ScreamingBedWars : <https://www.spigotmc.org/resources/63714/> · <https://screamingsandals.gitbook.io/screaming-bedwars/>
- Spleef_reloaded (steve4744) : <https://www.spigotmc.org/resources/118673/>
- MurderMystery (Plugily-Projects) : <https://www.spigotmc.org/resources/66614/> · <https://wiki.plugily.xyz/murdermystery/>
- OITC (Despical) : <https://www.spigotmc.org/resources/81185/>
- BentoBox + AOneBlock : <https://docs.bentobox.world/> · <https://github.com/BentoBoxWorld/AOneBlock>
- VoidWorldGenerator (HydrolienF) : <https://www.spigotmc.org/resources/113931/>
- Advanced Portals (sekwah41) : <https://modrinth.com/plugin/advanced-portals>
- itzg/minecraft-server docs (env vars plugin auto-install) : <https://docker-minecraft-server.readthedocs.io/en/latest/mods-and-plugins/>
- API Spiget : <https://spiget.org/>
- WorldGuard flags : <https://worldguard.enginehub.org/en/latest/regions/flags/>
- Schematic inventory : [`assets/schematics/README.md`](../assets/schematics/README.md)
- Workflow jars manuels : [`plugins/manual/README.md`](../plugins/manual/README.md)
