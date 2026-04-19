# Schematics — sauvegardes de l'ancien serveur 1.8

Archive des `*.schematic` exportés depuis `mc-server-old/plugins/WorldEdit/`.
Format MCEdit legacy (1.8) — WorldEdit 7.x sur Paper 1.21 les lit sans souci,
mais ne peut plus les ré-écrire dans ce format (utilise `.schem` pour les
nouveaux exports).

## Déploiement vers le pod mc-main

```bash
make push-schematics
```

Puis en jeu :

```
//schem list
//schem load hub-skywars
//paste
```

## Inventaire (18 cartes, ~864 Ko)

### Hubs (6)

| Fichier | Usage d'origine |
|---|---|
| `hub.schematic` | Hub principal (248 Ko, le plus gros) |
| `hub-bigold.schematic` | Ancien hub avant refonte |
| `hub-faction.schematic` | Hub du serveur Faction |
| `hub-skyblock.schematic` | Hub SkyBlock |
| `hub-skywars.schematic` | Hub SkyWars actuel |
| `hub-skywars-old.schematic` | Hub SkyWars ancienne version |

### SkyWars — arènes (11)

| Fichier | Notes |
|---|---|
| `Sky_Duel.schematic` | Map 1v1 |
| `skywars-ballon.schematic` | Montgolfière |
| `skywars-ballon-oringin.schematic` | Montgolfière version originale |
| `skywars-bones.schematic` | Thème ossements |
| `skywars-classico.schematic` | Map classique |
| `skywars-duels.schematic` | Duels |
| `skywars-dune.schematic` | Désert |
| `skywars-frozen.schematic` | Glace |
| `skywars-jungle.schematic` | Jungle |
| `skywars-nethugly.schematic` | Nether-themed |
| `skywars-tree.schematic` | Arbre géant |

### Mini-games (1)

| Fichier | Usage |
|---|---|
| `tntrun-classico.schematic` | Map TNTRun |

## Workflow de restauration d'une carte sur un monde vide

1. **Créer un monde plat** (ou vide) via Multiverse :
   ```
   make cmd ARGS="mv create main_hub normal -t flat"
   ```
2. **TP dans le monde**, idéalement debout sur un spot propre :
   ```
   make cmd ARGS="mv tp Zoyern main_hub"
   ```
3. **Coller le schematic** :
   ```
   //schem load hub-skywars
   //paste -a            # -a = skip air (n'écrase pas avec de l'air)
   ```
4. **Définir le spawn** au centre de la map :
   ```
   /setworldspawn
   ```
5. **Protéger** avec WorldGuard si lobby public :
   ```
   //pos1 ; //pos2        # après sélection de la zone
   /rg define lobby
   /rg flag lobby pvp deny
   /rg flag lobby build deny
   ```
