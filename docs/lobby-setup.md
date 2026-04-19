# Lobby MineShark — guide de setup

Ce document explique comment assembler un lobby « pro » (style Hypixel/CubeCraft light) sur notre serveur principal Paper, depuis un monde vide jusqu'aux permissions LuckPerms finales, en passant par la paste performante du schematic et l'activation des mini-games SkyWars + TNTRun.

> **Note fork** — guide rédigé pour Paper (défaut depuis avril 2026). Pour les features Purpur exclusives (double-jump, etc.) voir `docs/forks-comparison.md`. La plupart de ce guide est plugin-agnostique et marche sur les deux forks.

## Convention de nommage des mondes

Le défaut Minecraft `world` est gardé pour rien. On remplace par des noms parlants :

- **`hub`** — le lobby (anciennement `world` ou `lobby`). Terme standard de l'industrie (Hypixel, CubeCraft, Mineplex).
- **`main`** — le monde survie principal.
- **`main_nether` / `main_the_end`** — dimensions associées à `main`.
- **`sw-<nom>`**, **`sg-<nom>`**… — mini-games préfixés pour le tri dans `/mv list`.

Cette convention s'applique à tous les exemples ci-dessous : remplace mentalement `hub` par le nom que tu préfères si tu veux diverger.

On suppose que :
- Le serveur principal tourne en Paper 1.21.x derrière Velocity.
- La map du hub est disponible (schematics dans `assets/schematics/`, déployés via `make push-schematics` puis `//schem load` + `//paste -a`).
- Les plugins par défaut sont installés (LuckPerms, WorldEdit, WorldGuard, Multiverse-Core, DecentHolograms, PlaceholderAPI, EssentialsX, CoreProtect, Chunky — cf. `docs/plugins.md`).

## Philosophie

Un lobby doit faire trois choses et rien d'autre :

1. **Accueillir** — spawn propre, pas de mobs, pas de dégâts, pas de pluie.
2. **Orienter** — NPC ou signs vers les mini-games, les règles, le Discord.
3. **Impressionner** — double-jump, launchpads, hologrammes leaderboards, effets de particules.

Tout ce qui n'est pas dans ces trois piliers est du bruit. On reste minimaliste.

## 0. Repartir propre — wipe des mondes par défaut

Si tu as déjà paste le hub dans `world` (le monde par défaut) et que tu veux tout reprendre à zéro, c'est là. Sinon, saute à §1.

### 0.1 Faire de `hub` le monde par défaut (void)

Deux changements dans `k8s/main/deployment.yaml` (section `env:` du container `minecraft`) :

```yaml
- name: LEVEL
  value: "hub"                              # était "world" implicite
- name: LEVEL_TYPE
  value: "minecraft:flat"                   # pas de génération naturelle
- name: GENERATOR_SETTINGS
  value: '{"biome":"minecraft:the_void","layers":[]}'   # void absolu
- name: ALLOW_NETHER
  value: "FALSE"                            # pas de nether (on n'en veut pas en lobby)
```

Explication : `LEVEL=hub` dit à Paper « le monde par défaut s'appelle hub ». `LEVEL_TYPE=flat` + `GENERATOR_SETTINGS` void = génère RIEN (pas de grass, pas de bedrock, juste du void). Le schematic apportera son propre sol. `ALLOW_NETHER=false` empêche la création de `hub_nether` et `hub_the_end`.

Équivalent `docker-compose.yml` (section `environment:` de `main-paper`) :

```yaml
LEVEL: "hub"
LEVEL_TYPE: "minecraft:flat"
GENERATOR_SETTINGS: '{"biome":"minecraft:the_void","layers":[]}'
ALLOW_NETHER: "FALSE"
```

### 0.2 Supprimer les anciens mondes résiduels

Après avoir appliqué les changements (`make re`), Paper démarre et crée `hub/` (void) à côté des anciens `world/`, `world_nether/`, `world_the_end/`. On nettoie :

```bash
# On attend que mc-main soit UP avec le nouveau monde hub, puis :
kubectl exec -n mineshark deploy/mc-main -- sh -c '
  rm -rf /data/world /data/world_nether /data/world_the_end
  ls /data | head -20
'
```

Vérifie bien que tu vois `hub` dans le listing et PLUS `world*`. Plus de pollution.

### 0.3 Reset des joueurs (optionnel)

Les inventaires et positions sont stockés par UUID dans `/data/hub/playerdata/*.dat`. Les anciennes positions pointaient vers `world` qui n'existe plus → au prochain login, le jeu tombe sur le spawn de `hub`. Rien à faire.

Si tu veux vraiment repartir à zéro côté joueurs (perm aussi) :

```bash
kubectl exec -n mineshark deploy/mc-main -- sh -c 'rm -rf /data/hub/playerdata /data/hub/stats /data/hub/advancements'
# Et côté LuckPerms (si tu avais déjà des groupes assignés) :
make cmd ARGS="lp user Zoyern clear"
```

---

## 1. Configurer le monde `hub` via Multiverse

Si tu as appliqué §0, `hub` existe déjà (créé au boot par Paper, void absolu). Tu le configures en lobby :

```
make cmd ARGS="mv import hub normal"
make cmd ARGS="mv modify hub set gamemode adventure"
make cmd ARGS="mv modify hub set difficulty peaceful"
make cmd ARGS="mv modify hub set pvp false"
make cmd ARGS="mv modify hub set hunger false"
make cmd ARGS="mv modify hub set weather false"
make cmd ARGS="mv modify hub set autoHeal true"
make cmd ARGS="mv modify hub set keepSpawnInMemory true"
make cmd ARGS="mv modify hub set autoLoad true"
```

Si tu n'as PAS appliqué §0, crée un monde dédié (FLAT classique avec bedrock/grass) à la place du void :

```
make cmd ARGS="mv create hub normal -t FLAT -g FLAT -s 0"
# puis mêmes mv modify ci-dessus
```

Traduction rapide :

- `adventure` = blocs incassables sans outil spécial. Plus strict que survival.
- `peaceful` = pas de mobs hostiles.
- `keepSpawnInMemory true` = spawn toujours chargé → téléports instantanés.

Prérequis avant paste : `make push-schematics` depuis le host pour pousser `assets/schematics/*.schematic` dans le pod (inventaire dans `assets/schematics/README.md`).

## 1bis. Paste centré sur 0, 0, 0 — méthode propre

Le piège du paste « brut » : `//paste` utilise l'offset d'origine enregistré dans le schematic, qui correspond à l'endroit où le mec original avait copié. Pour `hub.schematic` (1.8), c'est aléatoire → le centre atterrit à `45, 63, 30`. Moche.

La méthode en deux passes pour avoir le centre à `0, Y, 0` :

**Passe 1 — paste exploratoire pour repérer le centre**

```
make cmd ARGS="mv tp Zoyern hub"
# En jeu, haut dans le void :
/tp 0 120 0
//perf neighbors off           # désactive physique pendant paste (évite freeze)
//schem load hub
//paste -a -o                  # -o = paste à l'origine du schem (= à toi)
```

Marche sur la map, trouve le point qui doit être le centre du lobby (la place, le portail central). Note ses coords avec F3. Exemple : `X=37, Y=85, Z=22`.

**Passe 2 — re-copy avec ton bon centre, puis re-paste à 0,0,0**

```
# Place-toi PILE au centre souhaité :
/tp 37 85 22

# Sélectionne toute la zone (vise les 2 coins extrêmes) :
//pos1                         # coin bas-gauche (viser un bloc)
/tp <coin_opposé_coords>
//pos2                         # coin haut-droit

# Copy AVEC TOI comme origine :
//copy
//schem save hub-centered -f

# Wipe la zone actuelle :
//set air

# Repaste centré en 0, 100, 0 :
/tp 0 100 0
//schem load hub-centered
//paste -a -o
/setworldspawn
//perf neighbors on            # restaure physique
```

Le centre du lobby est maintenant à `0, 100, 0`. `/spawn` amène pile au milieu.

**Bonus — versionner le schem centré dans le repo :**

```bash
pod=$(kubectl get pod -n mineshark -l app=mc-main -o jsonpath='{.items[0].metadata.name}')
kubectl cp mineshark/$pod:/data/plugins/WorldEdit/schematics/hub-centered.schem \
    assets/schematics/hub-centered.schem
git add assets/schematics/hub-centered.schem
git commit -m "save hub-centered schem (origine 0,0,0)"
```

Prochaine install = `//schem load hub-centered ; //paste -a -o` à `0 100 0` et fini. Fait-le AUSSI pour toutes les maps SkyWars après centrage (voir `docs/minigames.md`).

## 1ter. Performance paste — éviter le freeze de 5 min

Le `//paste` brut sur `hub.schematic` (248 Ko, ~500k blocs) a gelé Paper ~280s en prod le 19/04. Cause = updates de lighting + physique synchrones sur le main thread. Les leviers :

```
//perf neighbors off       # coupe updates physique (redstone, gravité, leaves)
//perf relight minimal     # relight à minima pendant paste
//paste -a                 # skip air = 10x moins d'écritures
```

Après la paste :

```
//perf neighbors on
//perf relight full
```

**Upgrade Phase 2 — FAWE** (FastAsyncWorldEdit) : drop-in replacement multi-threaded, ne bloque jamais le main thread. Standard pour schematics > 100 Ko. Lit les MCEdit 1.8 sans souci. Migration :

1. Dans `.env`, remplace `worldedit` par `fastasyncworldedit` dans `PLUGINS_MODRINTH`
2. Sur le VPS :

```bash
kubectl exec -n mineshark deploy/mc-main -- sh -c 'rm -f /data/plugins/worldedit-bukkit-*.jar'
make re
```

À tester en dev d'abord (quelques commandes diffèrent légèrement).

## 2. Double-jump (Purpur uniquement — désactivé en Paper)

> **Skip cette section en Paper.** Paper n'a pas de double-jump natif. Les options :
>
> 1. Repasser à Purpur (change `SERVER_TYPE=PURPUR` dans `.env`, `make re`, et applique la config `purpur-world.yml` ci-dessous).
> 2. Installer un plugin dédié (`ezDoubleJump`, `DoubleJumpPlus`). À ajouter dans `PLUGINS_MODRINTH` de `.env`.
> 3. Laisser tomber (le lobby reste très bien sans).

Pour référence, en Purpur, on édite `data/main/hub/purpur-world.yml` (généré au 1er boot) :

```yaml
# data/main/hub/purpur-world.yml
movement:
  double-jump:
    enabled: true
    add-velocity: 0.5
```

Puis `/mv reload` ou `/purpur reload`. Le double-jump est automatiquement désactivé dès que le joueur quitte le monde `hub`. C'est là toute la force des world-settings Purpur.

## 3. Définir la région safe-zone avec WorldGuard

Le but : empêcher tout grief dans le `hub` (même par un admin en mode survival par erreur).

```
# Se placer dans un coin en haut du hub, puis :
//pos1
# Aller au coin opposé en bas :
//pos2

# Créer la région couvrant toute la zone sélectionnée :
/rg define hub-safe

# Flags essentiels :
/rg flag hub-safe build deny
/rg flag hub-safe pvp deny
/rg flag hub-safe mob-damage deny
/rg flag hub-safe fall-damage deny
/rg flag hub-safe mob-spawning deny
/rg flag hub-safe fire-spread deny
/rg flag hub-safe block-break deny
/rg flag hub-safe block-place deny
/rg flag hub-safe chest-access deny
/rg flag hub-safe use allow
/rg flag hub-safe interact allow

# Bienvenue à l'entrée de zone :
/rg flag hub-safe greeting &bBienvenue au lobby MineShark !
```

Vérifie avec `/rg info hub-safe`. Flags principaux expliqués :

- `build deny` = personne ne peut modifier les blocs. Les admins passent par `-g owners` ou le bypass `/rg bypass`.
- `interact allow` + `use allow` = on peut cliquer sur les NPC, les boutons, ouvrir les signs. Sans ces deux-là le lobby est « mort ».
- `mob-spawning deny` = pas besoin de passer en peaceful si on met ça (redondant avec Multiverse mais ceinture + bretelles).

## 4. NPC & hologrammes

Les hologrammes via DecentHolograms (sans plugin Citizens, moins lourd) :

```
/dh create lobby-title
/dh line lobby-title 1 &b&lMineShark
/dh line lobby-title 2 &7%server_online%/%server_max_players% joueurs
/dh line lobby-title 3 &eRejoins un mini-game ci-dessous !

# Placeholder %server_online% = PlaceholderAPI. Installé en stack par défaut.
# DecentHolograms refresh auto toutes les 20 ticks.
```

Pour un NPC qui téléporte vers un mini-game, on fait sans Citizens pour rester light : un armor stand invisible + un sign au-dessus, combiné à un `/warp` Essentials.

```
# Place un armor stand là où tu veux le NPC :
/summon armor_stand ~ ~ ~ {Invisible:1b,NoGravity:1b,ShowArms:1b,Marker:0b}

# Au-dessus, un hologramme :
/dh create npc-skywars
/dh move npc-skywars ~ ~1.8 ~
/dh line npc-skywars 1 &6&l[SKYWARS]
/dh line npc-skywars 2 &7Clic droit pour rejoindre
```

Côté interaction : EssentialsX `/warp skywars` + un plugin PlayerInteractAtEntityEvent custom, ou plus simple : un pressure plate juste devant l'NPC qui exécute `/warp skywars` via un command block (rappel : command block activable pour admin seulement via `/gamerule commandBlockOutput false` puis `/setblock` avec NBT).

Plus propre à long terme : un petit plugin custom « NPCRouter » (~200 lignes Java) qui écoute `PlayerInteractAtEntityEvent` et mappe armor_stand UUID → commande serveur.

## 5. Configuration LuckPerms de base

Trois groupes suffisent au début : `default`, `vip`, `admin`.

```
/lp creategroup default
/lp creategroup vip
/lp creategroup admin

# default : permissions minimales lobby
/lp group default permission set essentials.spawn true
/lp group default permission set essentials.msg true
/lp group default permission set multiverse.portal.access.* true

# vip : cosmétique + petites features
/lp group vip parent add default
/lp group vip permission set essentials.fly true     # flight hub uniquement (cf §6)
/lp group vip meta setprefix 10 "&6[VIP] "

# admin : bypass total
/lp group admin permission set * true
/lp group admin meta setprefix 100 "&c[Admin] "

# Attribue toi-même admin :
/lp user <TON_PSEUDO> parent add admin
```

Le `&6` etc. sont des codes couleur Minecraft. `meta setprefix 10` = weight 10, le prefix du weight le plus haut est affiché (donc admin `100` écrase vip `10`).

## 6. Fly hub (VIP) sans fly survie

Piège classique : `essentials.fly` = fly PARTOUT. On veut fly **uniquement au hub**. Solution : permissions conditionnelles via LuckPerms `context`.

```
/lp group vip permission set essentials.fly true world=hub
```

La perm est active uniquement si le joueur est dans le monde `hub`. Dans la survie elle se désactive automatiquement. Même logique pour le double-jump si on voulait le réserver aux VIP :

```
/lp group default permission unset purpur.double-jump
/lp group vip permission set purpur.double-jump true world=hub
```

Par défaut on laisse le double-jump ouvert à tous dans le hub — c'est un wow-effect, pas un truc payant.

## 7. Spawn global & spawn par monde

Pour que `/spawn` amène toujours au hub (même depuis la survie) :

```
# Dans Essentials, force le respawn au hub :
# config/Essentials/config.yml :
respawn-at-home: false
respawn-listener-priority: high
# ajoute :
spawn-priority: essentials

# Dans config/Multiverse-Core/config.yml :
firstspawnworld: hub
firstspawnoverride: true
```

Résultat : première connexion → hub. Après mort → hub (sauf si `/sethome` côté survie et respawn-at-home activé, ce qu'on désactive ici volontairement pour éviter les ambiguïtés).

Pour la survie, on fait simplement `/mv setspawn` sur le monde `main` depuis l'endroit où on veut que les joueurs atterrissent en passant `/mv tp main`.

## 7bis. MOTD & compteurs dynamiques

Trois endroits où afficher du texte stylé avec des compteurs live. Tous utilisent PlaceholderAPI (déjà installé).

### 7bis.1 MOTD ping (l'écran avant de se connecter)

Statique par défaut dans `.env` (`MAIN_MOTD=...`). Pour du dynamique (compteur joueurs, phrase qui change selon l'heure, etc.) installe **AdvancedServerList** côté Velocity :

```bash
# Ajoute dans velocity plugins via PLUGINS (k8s/velocity/deployment.yaml ou docker-compose.yml) :
#   https://github.com/Andre601/AdvancedServerList/releases/latest/download/AdvancedServerList-Velocity.jar
```

Config dans `data/velocity/plugins/AdvancedServerList/profiles/default.yml` :

```yaml
priority: 1
motd:
  - "&b&lMineShark &8| &f%server_online%/%server_max%&7 en ligne"
  - "&aSkyWars &8• &6TNTRun &8• &cSurvie"
```

`%server_online%` est rafraîchi à chaque ping du serveur (toutes les secondes côté client). Tu peux ajouter des conditions (`hide_players`, `favicon` custom par hostname, etc.).

### 7bis.2 Holograms dans le lobby (leaderboards, compteurs)

DecentHolograms + PlaceholderAPI — déjà en place. Exemple compteur joueurs en vol au-dessus du spawn :

```
/dh create spawn-title
/dh addline spawn-title &b&lMINESHARK
/dh addline spawn-title
/dh addline spawn-title &7Connectés : &e%server_online%&7/%server_max_players%
/dh addline spawn-title &7TPS : &a%server_tps_1%
/dh setrefresh spawn-title 40               # refresh toutes les 2s (40 ticks)
/dh move spawn-title                        # place à ta position
```

Pour des leaderboards top-kills/top-skywars, installe l'extension PAPI `Statistic` :

```
/papi ecloud download Statistic
/papi reload
```

Puis placeholders du style `%statistic_player_kills_top_1%`, `%statistic_player_kills_top_1_name%`, etc.

### 7bis.3 Tab list stylée (avec compteurs)

Plugin **TAB** (Modrinth slug: `tab-was-taken`). Affiche header/footer customs avec PAPI :

```yaml
# plugins/TAB/config.yml
header: "&b&lMineShark &8- &f%server_online%/%server_max% joueurs"
footer: "&7discord.gg/mineshark &8| &eTPS: %server_tps_1%"
```

Si tu le mets dans `PLUGINS_MODRINTH` : `tab-was-taken`.

### 7bis.4 Scoreboard latéral

Plugin **FeatherBoard** (payant) ou alternatives gratuites : **AnimatedScoreboard** / **Scoreboard Revision**. Même logique : un YAML avec des lignes + PAPI. À voir en phase 2 si tu veux pas sur-charger visuellement le lobby.

## 8. Checklist ouverture publique

Avant de laisser ton lobby au public :

```
[ ] /rg info hub-safe → build/pvp/mob-damage sont en deny
[ ] Teste en compte non-admin : pas moyen de casser un bloc, pas de dégâts
[ ] Double-jump fonctionne au lobby mais pas en survie
[ ] /spawn amène au bon endroit
[ ] /msg, /tpa désactivés au lobby si on veut forcer le chat global
[ ] MOTD custom dans .env : MAIN_MOTD="§b§lMineShark §7- §aSurvie"
[ ] enable-command-block: false dans server.properties (anti-grief)
[ ] white-list OFF seulement quand tout est testé
[ ] spawn-protection: 0 dans server.properties (WorldGuard s'en charge mieux)
```

## 9. Débug / commandes utiles

```
/tps                               # TPS natif Paper (remplace /spark tps)
/mspt                              # temps serveur par tick (Paper natif)
/mv list                           # liste tous les mondes chargés
/co inspect                        # mode inspection CoreProtect (clique un bloc)
/co rollback u:<user> t:1h         # rollback 1h pour l'utilisateur
/lp user <name> info               # voir toutes les perms effectives
/reload confirm                    # recharge plugins (⚠ à éviter en prod, préfère rollout restart)
```

Depuis l'extérieur du jeu :

```
make cmd ARGS="tps"                # côté host, via RCON
make logs-main                     # tail des logs en direct
```

## 10. Pour aller plus loin (Phase 2)

Quand le hub est stable, on peut rajouter :

- **Cosmétiques** : plugin custom « Cosmetics » — particles trails, gadgets, hats. À écrire nous-mêmes (~1000 lignes, refait ce qui existe en closed-source sur Hypixel).
- **Leaderboards dynamiques** : DecentHolograms + PlaceholderAPI expansion `Statistic` → classements top-kills, top-skywars live.
- **NPC routing custom** : voir §4, un petit plugin interne qui mappe UUID d'armor_stand → commande. Plus extensible que des pressure plates.
- **Particles parkour** : des zones en Multiverse avec WorldEdit command blocks qui téléportent sur un échec de saut, pour un petit parkour lobby annexe.
- **Queue mini-games** : BungeeCord/Velocity queue via RedisBungee ou un plugin maison. Seulement quand on a plusieurs serveurs mini-games distincts, pas avant.

## Références

- Purpur world-settings : <https://purpurmc.org/docs/Configuration/>
- WorldGuard flags : <https://worldguard.enginehub.org/en/latest/regions/flags/>
- LuckPerms contexts : <https://luckperms.net/wiki/Context>
- Multiverse-Core commands : <https://dev.bukkit.org/projects/multiverse-core/pages/commands>
- DecentHolograms : <https://wiki.decentholograms.eu/>
