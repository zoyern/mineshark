# Mini-games MineShark — SkyWars & TNTRun

Guide pragmatique pour faire tourner les 11 maps SkyWars et `tntrun-classico` récupérées de l'ancien serveur 1.8. Ciblé Paper 1.21.4, compatible avec le stack plugins déjà installé.

> **Honnêteté sur l'état de l'art mini-games en 1.21.4** — le landscape des plugins mini-games pour Paper 1.21.x est fragmenté : beaucoup de plugins mythiques (SkyWarsReloaded, TNTRun_reloaded) ne sont plus maintenus ou pas encore portés. Trois approches s'offrent à toi, chacune avec ses trade-offs. Je te présente les 3 et ma recommandation à la fin.

## Sommaire

- [Les 3 approches](#les-3-approches)
- [Approche A — plugin tout-en-un](#approche-a--plugin-tout-en-un-moins-de-code-moins-de-flexibilité)
- [Approche B — plugin custom perso](#approche-b--plugin-custom-perso-plus-de-code-100-dans-ton-style)
- [Approche C — hybride maintenant / custom plus tard](#approche-c--hybride-démarre-vite-migre-plus-tard-recommandé)
- [SkyWars — setup des 11 maps](#skywars--setup-des-11-maps)
- [TNTRun — setup de la tour](#tntrun--ajouter-les-tnt-à-la-tour)
- [Intégration lobby (NPC + warps)](#intégration-lobby-npc--warps)
- [Checklist test](#checklist-test)

## Les 3 approches

### Approche A — plugin tout-en-un (moins de code, moins de flexibilité)

Tu prends un plugin qui gère tout : lobby mini-game, kits, queue, reset automatique de la map, death/respawn, chest loot, etc.

**Candidats SkyWars sur Paper 1.21.4 (à vérifier à jour sur Modrinth avant install) :**

- `SkyWarsReloaded` — mythique mais maintenance sporadique. Check les dernières versions sur <https://modrinth.com/plugin/skywarsreloaded>
- `BedWars1058` (fork SkyWars) — certains forks ajoutent un module SW
- `MBedwars` — payant, support SW en addon
- `SimpleSkyWars` / forks communautaires — à évaluer au cas par cas

**TNTRun :**

- `TNTRun_reloaded` — historique, dernière release compatible Paper à vérifier
- `SimpleTNTRun`
- Divers forks GitHub

**Avantage** : tu installes, tu configures un YAML, ça marche.
**Risque** : dépendance sur un plugin peu maintenu, surprises à chaque update Paper, features verrouillées par le plugin. Plus les forks sont obscurs, plus c'est fragile.

### Approche B — plugin custom perso (plus de code, 100% dans ton style)

Tu écris ton propre mini-game framework en Java. Tu contrôles tout : UX, esthétique, features.

**Effort :**

- Un SkyWars basique (1 arène, 8 cages, chest loot, death = spectator, dernier debout gagne) = ~1500 lignes Java. Avec map rotation, queue multi-arènes, kits : ~3000-5000 lignes.
- Un TNTRun basique (sable/TNT disparaît sous les pieds, dernier debout gagne) = ~200-400 lignes. C'est littéralement un `BlockBreakEvent` + un scheduler.

**Avantage** : tu as exactement ce que tu veux, tu contrôles l'UX (qui est ta priorité : « propre pro et fun mais sobre »). Aucune dépendance fragile. Et c'est un excellent terrain de jeu pour apprendre l'API Paper.
**Coût** : du temps de dev. Mais TNTRun est faisable en un après-midi.

### Approche C — hybride (démarre vite, migre plus tard) ← recommandé

1. **Aujourd'hui** : TNTRun en custom (rapide, fun, tu apprends l'API), SkyWars avec WorldGuard + WorldEdit + commandes custom (voir ci-dessous — limité mais jouable entre potes).
2. **Phase 2** : quand tu as le temps, code ton SkyWars framework custom. Pendant ce temps l'infra tourne, les potes jouent déjà.
3. **Jamais** : tu ne dépends d'aucun plugin obscur qui va casser au prochain 1.21.5.

C'est l'approche qui colle le mieux à ton style : « je préfère coder des choses que d'avoir un truc nul moche qui fonctionne à moitié ». Mais en attendant d'avoir codé, tu as un truc qui marche.

## SkyWars — setup des 11 maps

Ton inventaire (voir `assets/schematics/README.md`) :

```
Sky_Duel, skywars-ballon, skywars-ballon-oringin, skywars-bones,
skywars-classico, skywars-duels, skywars-dune, skywars-frozen,
skywars-jungle, skywars-nethugly, skywars-tree
```

### Étape 1 — un monde par arène (Multiverse)

Un monde `void` par arène, tous préfixés `sw-` pour le tri dans `/mv list` :

```bash
for map in classico dune frozen jungle tree ballon bones nethugly duels sky-duel; do
    make cmd ARGS="mv create sw-$map normal -t FLAT -g FLAT -s 0"
    make cmd ARGS="mv modify sw-$map set gamemode adventure"
    make cmd ARGS="mv modify sw-$map set pvp true"
    make cmd ARGS="mv modify sw-$map set difficulty normal"
    make cmd ARGS="mv modify sw-$map set autoLoad false"   # ne charge QUE quand on y TP
done
```

`autoLoad false` = économise RAM : la map n'est chargée que quand un joueur y va. Gros gain avec 11 arènes.

### Étape 2 — paste chaque schematic dans sa map

Pour chaque arène (exemple `classico`) :

```
make cmd ARGS="mv tp Zoyern sw-classico"
# En jeu :
/tp 0 100 0
//perf neighbors off
//schem load skywars-classico
//paste -a -o
/setworldspawn
//perf neighbors on
```

Répète pour les 11 maps. Profite-en pour noter les **coords des cages** (spawns des joueurs) — souvent 8 îlots autour du centre à +100 / -100 blocs. Tu en auras besoin pour l'étape suivante.

### Étape 3 — définir les régions WorldGuard

Pour chaque arène, deux régions :

```
# Arène entière (zone de jeu) :
//pos1 ; //pos2                       # sélectionne tout le playfield
/rg define sw-classico-arena
/rg flag sw-classico-arena pvp allow
/rg flag sw-classico-arena block-break allow     # casser les chests, les îlots, etc.
/rg flag sw-classico-arena block-place allow     # bridger

# Centre (barrière jusqu'au début de partie) :
/rg define sw-classico-cages -g
/rg flag sw-classico-cages pvp deny
/rg flag sw-classico-cages invincibility allow
```

### Étape 4 — kits et chest loot (approche sans plugin dédié)

**Kits** via EssentialsX (déjà installé) :

```yaml
# plugins/Essentials/kits.yml
kits:
  sw-basic:
    delay: 0
    items:
      - wooden_sword 1
      - wooden_pickaxe 1
      - bread 8
      - oak_planks 16
```

`/kit sw-basic` donne le stuff au joueur.

**Chest loot** : remplis manuellement les coffres de chaque map avec un loot varié. Pour automatiser la régénération entre deux parties, il faut un plugin (ou ton SkyWars custom). En attendant, manuellement c'est OK pour tester.

### Étape 5 — commandes rapides pour lancer une partie

Écris un petit script Makefile :

```makefile
# make/minigames.mk
sw-start: ## Démarre une partie SkyWars sur la map <MAP>. Usage: make sw-start MAP=classico
	@test -n "$(MAP)" || (echo "❌ Usage: make sw-start MAP=classico"; exit 1)
	@make cmd ARGS="mv load sw-$(MAP)"
	@make cmd ARGS="mvtp Zoyern sw-$(MAP)"
	@echo "✓ Arène sw-$(MAP) lancée. Les joueurs /tp sw-$(MAP) pour join."

sw-reset: ## Recharge une map depuis le schematic (reset inter-partie). Usage: make sw-reset MAP=classico
	@test -n "$(MAP)" || exit 1
	@make cmd ARGS="mv unload sw-$(MAP)"
	@# Wipe et repaste — nécessite un script custom plus bas
```

C'est basique mais jouable à 3-4 entre potes. Pour du compétitif automatisé, il te faut l'approche B ou un plugin dédié.

## TNTRun — ajouter les TNT à la tour

Ton `tntrun-classico.schematic` est la tour sans les TNT. Deux options :

### Option 1 — plugin TNTRun

Si tu trouves un plugin maintenu pour 1.21.4 :

```bash
# À chercher sur Modrinth : tntrun, tntrun-reloaded, simple-tntrun
# Ajoute le slug dans PLUGINS_MODRINTH et make re
```

Config type :

```yaml
arenas:
  classico:
    min-players: 2
    max-players: 12
    lobby: "hub,0,100,0"
    spawn: "sw-tntrun,0,120,0"
    floors:
      - {pos1: "-30,110,-30", pos2: "30,110,30"}   # étage haut
      - {pos1: "-30,100,-30", pos2: "30,100,30"}   # étage moyen
      - {pos1: "-30,90,-30", pos2: "30,90,30"}     # étage bas
```

### Option 2 — TNTRun custom (~300 lignes Java)

La logique est triviale. Pseudo-code :

```java
@EventHandler
public void onPlayerMove(PlayerMoveEvent e) {
    if (!arena.contains(e.getPlayer())) return;
    Block below = e.getPlayer().getLocation().subtract(0, 1, 0).getBlock();
    if (below.getType() == Material.SAND || below.getType() == Material.TNT) {
        // Planifie la disparition dans 300ms
        Bukkit.getScheduler().runTaskLater(plugin, () -> below.setType(Material.AIR), 6L);
    }
}
```

Ajoute : détection mort (y < 50), dernier debout = victoire, reset des blocs après la partie (sauvegarde l'état initial via un WorldEdit `//copy` au démarrage, `//paste -a` à la fin).

Pour remplir la tour de TNT/sable **avant d'activer le plugin**, WorldEdit :

```
# TP au centre de chaque étage de la tour, sélectionne l'étage, remplis :
//pos1 ; //pos2
//set sand              # ou //set 50%sand,50%tnt pour le look classique
```

## Intégration lobby (NPC + warps)

Dans le hub, un NPC/panneau par mini-game pointant vers son warp.

```
# Crée les warps (EssentialsX) :
/warp set sw-lobby        # au-dessus du sol du hub, zone SkyWars
/warp set tntrun-lobby    # idem TNTRun

# Pour chaque mini-game, un armor stand + hologramme (cf. lobby-setup.md §4) :
/summon armor_stand ~ ~ ~ {Invisible:1b,NoGravity:1b,Marker:1b,Tags:["skywars-npc"]}

/dh create sw-npc
/dh addline sw-npc &6&l⚔ SKYWARS ⚔
/dh addline sw-npc &7%server_online% joueurs en ligne
/dh addline sw-npc &eClic droit pour rejoindre
```

Interaction → pressure plate invisible avec command block :

```
/fill ~ ~-1 ~ ~ ~-1 ~ light_weighted_pressure_plate
/setblock ~ ~-2 ~ command_block{Command:"warp sw-lobby @p",auto:1b}
```

Ou mieux : un mini-plugin custom « NPCRouter » (~150 lignes Java) qui écoute `PlayerInteractAtEntityEvent` sur les armor_stand taggés et exécute le warp. Beaucoup plus propre que les command blocks.

## Checklist test

Avant de tester avec un ami :

```
[ ] /mv list montre bien toutes les sw-* et tntrun
[ ] /mv tp sw-classico fonctionne, la map s'affiche
[ ] WorldGuard protège chaque arène (block-break OK en arena, deny en cages)
[ ] Kit sw-basic se donne : /kit sw-basic
[ ] Les chests des îles ont du loot
[ ] /warp sw-lobby fonctionne depuis le hub
[ ] Les NPC/holograms dans le hub pointent vers les bons warps
[ ] En tombant dans le vide, on meurt et on respawn au hub (via §7 lobby-setup.md)
[ ] TP au hub après une partie = automatique (à coder dans le plugin, ou manuel)
```

## Ma recommandation concrète

1. **Cette semaine** : applique §0 du `lobby-setup.md` (hub propre à 0,0,0) + paste les 11 arènes SkyWars (étapes 1 et 2 ici). Pas besoin de plugin mini-game pour l'instant — juste joue à la main : tp, /kit, /tp hub à la fin. C'est bourrin mais tu peux déjà jouer.

2. **Semaine prochaine** : code un petit TNTRun custom (~300 lignes). Ça te sert de terrain d'apprentissage pour l'API Paper et le concept de « mini-game framework ». Branche-le sur ta map `tntrun-classico`.

3. **Plus tard** : extends le framework pour SkyWars (~1500 lignes). Tu auras un système maison propre, pas de dépendances fragiles, 100% ton style.

L'option plugin tout-en-un (A) reste ouverte si tu veux du résultat immédiat sur SkyWars — mais vérifie bien la date de dernière release 1.21.4 avant d'install.

## Références

- Paper API docs : <https://jd.papermc.io/paper/1.21.4/>
- WorldGuard flags : <https://worldguard.enginehub.org/en/latest/regions/flags/>
- PlayerInteractAtEntityEvent : <https://jd.papermc.io/paper/1.21.4/org/bukkit/event/player/PlayerInteractAtEntityEvent.html>
- Schematic inventory : `assets/schematics/README.md`
