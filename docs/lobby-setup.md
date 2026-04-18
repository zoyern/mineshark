# Lobby MineShark — guide de setup

Ce document explique comment assembler un lobby « pro » (style Hypixel/CubeCraft light) sur notre serveur principal Purpur, une fois que la map du hub est déployée depuis l'ancien serveur. Il va du `make re` initial jusqu'aux permissions LuckPerms finales.

## Convention de nommage des mondes

Le défaut Minecraft `world` est gardé pour rien. On remplace par des noms parlants :

- **`hub`** — le lobby (anciennement `world` ou `lobby`). Terme standard de l'industrie (Hypixel, CubeCraft, Mineplex).
- **`main`** — le monde survie principal.
- **`main_nether` / `main_the_end`** — dimensions associées à `main`.
- **`sw-<nom>`**, **`sg-<nom>`**… — mini-games préfixés pour le tri dans `/mv list`.

Cette convention s'applique à tous les exemples ci-dessous : remplace mentalement `hub` par le nom que tu préfères si tu veux diverger.

On suppose que :
- Le serveur principal tourne en Purpur 1.21.x derrière Velocity.
- La map du hub a été importée (via schematic WorldEdit) dans `data/main/hub/` ou via `make import-map`.
- Les plugins par défaut sont installés (LuckPerms, WorldEdit, WorldGuard, Multiverse-Core, DecentHolograms, PlaceholderAPI, EssentialsX — cf. `docs/plugins.md`).

## Philosophie

Un lobby doit faire trois choses et rien d'autre :

1. **Accueillir** — spawn propre, pas de mobs, pas de dégâts, pas de pluie.
2. **Orienter** — NPC ou signs vers les mini-games, les règles, le Discord.
3. **Impressionner** — double-jump, launchpads, hologrammes leaderboards, effets de particules.

Tout ce qui n'est pas dans ces trois piliers est du bruit. On reste minimaliste.

## 1. Créer le monde `hub` via Multiverse

```
/mv create hub normal -t FLAT -g FLAT -s 0
/mv modify set gamemode adventure hub
/mv modify set difficulty peaceful hub
/mv modify set pvp false hub
/mv modify set hunger false hub
/mv modify set weather false hub
/mv modify set autoHeal true hub
/mv modify set keepSpawnInMemory true hub
/mv modify set autoLoad true hub
```

Traduction rapide :

- `adventure` = les joueurs ne peuvent pas casser les blocs (sans outil spécial). Plus strict que `survival`, plus permissif que `spectator`.
- `peaceful` = pas de mobs hostiles.
- `keepSpawnInMemory true` = le spawn reste chargé même quand il n'y a personne → téléports instantanés.

Une fois la map importée (schematic ou copie de dossier) :

```
/mv import hub normal    # si on a copié un dossier /data/main/hub
/mv setspawn             # depuis l'endroit où on veut que /spawn amène
```

## 2. Activer double-jump UNIQUEMENT sur `hub`

Dans `config/purpur.yml` on a laissé `movement.double-jump.enabled: false` par défaut. On l'override juste pour le monde `hub`.

Crée/édite `data/main/hub/purpur-world.yml` (Purpur le génère au premier boot si absent) :

```yaml
# data/main/hub/purpur-world.yml
movement:
  double-jump:
    enabled: true
    add-velocity: 0.5
```

Puis `/mv reload` ou `/purpur reload`. Sans serveur restart. Le double-jump est ENSUITE désactivé automatiquement quand le joueur va sur n'importe quel autre monde (survie, mini-games). C'est là toute la force des world-settings Purpur.

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
/spark profiler --timeout 60       # profile 60s de CPU, sortie web
/spark tps                         # affiche TPS récent par monde
/mv list                           # liste tous les mondes chargés
/co inspect                        # mode inspection CoreProtect (clique un bloc)
/co rollback u:<user> t:1h         # rollback 1h pour l'utilisateur
/lp user <name> info               # voir toutes les perms effectives
/purpur reload                     # recharge purpur.yml + purpur-world.yml
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
