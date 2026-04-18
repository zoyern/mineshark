# Migration des maps 1.8 → 1.21

Guide dédié à la **récupération propre** des maps de l'ancien serveur MineShark (`mc-server-old/`, Spigot 1.8, fermé en 2016) vers le nouveau serveur Paper 1.21.x.

L'enjeu : récupérer les constructions (lobby, hub SkyWars, arènes) **sans corrompre les chunks** ni perdre les signes, coffres, têtes custom, etc.

---

## Pourquoi on ne peut PAS juste copier le dossier monde

Entre 1.8 (2014) et 1.21 (2024), Minecraft a changé **trois fois** le format de stockage des chunks :

| Version | Format | Ce qui casse |
|---|---|---|
| 1.8 → 1.13 | Refonte complète des block IDs (« flattening ») | stone:1 (granite) → minecraft:granite |
| 1.13 → 1.18 | Nouveaux biomes, hauteur monde doublée | Monde 1.8 chargé dans 1.18 = chunks vides de 0 à -64 |
| 1.18 → 1.21 | Nouveaux blocs (copper, trial chambers, etc.) | OK en général mais heightmaps à régénérer |

**Résultat** : si tu copies `mc-server-old/world/` dans `data/main/world/` et que tu démarres Paper 1.21, tu vas obtenir :
- des chunks **corrompus** (mélange de blocs qui n'existent plus),
- la perte des **NBT** de tous les signes, coffres à butin, têtes custom,
- une régénération sauvage des biomes qui casse l'esthétique.

On va donc **pas migrer le monde**, on va **extraire les constructions** via WorldEdit.

---

## La méthode propre : `//schem save` → `//schem load`

WorldEdit stocke les constructions dans un format **schematic** (`.schem` depuis 1.13, `.schematic` avant) qui est **agnostique de la version** du monde : il encode les blocs par leur nom (`minecraft:oak_planks`) et WorldEdit fait la correspondance avec la version cible.

### Étape 0 — Repartir d'un `mc-server-old/` vierge (recommandé)

Avant toute manip, on part d'un **cold backup** — une archive du serveur prise **à l'arrêt**, fichiers dans un état cohérent (par opposition au « hot backup » pris pendant que le serveur tourne, qui peut attraper des `.mca` en cours d'écriture et donc corrompus). Le zip `mc-server-old-backup.zip` à la racine du repo est ce cold backup de référence.

Pour réinitialiser proprement `mc-server-old/` depuis ce zip :

```bash
make old-server-reset
```

Ce que fait la cible :

1. Si `mc-server-old/` existe déjà → `backups/old-server-pre-reset-<timestamp>.tar.gz` (sécurité, on perd rien).
2. Supprime `mc-server-old/`.
3. Décompresse `mc-server-old-backup.zip` à la racine.

Variable override : `make old-server-reset OLD_BACKUP_ZIP=chemin/vers/autre.zip`.

### Étape 1 — Relancer l'ancien serveur 1.8 une dernière fois

Pour que WorldEdit puisse ouvrir le monde. **Le jar présent dans le repo est `spigot-1.8.7.jar`** (pas 1.8.8).

#### a. Préparer pour un boot rapide (fortement recommandé)

L'ancien serveur contient 43 mondes Multiverse. Par défaut, Multiverse charge **tous** les mondes au démarrage, chacun pré-génère son spawn → boot observé de ~7 min 20s. Un script transforme ça en ~30 s **et débloque les connexions directes** :

```bash
make old-server-prep       # alias de ./scripts/old-server-prep.sh
```

Ce qu'il fait (idempotent) :

1. **Cold backup** du dossier `mc-server-old/` dans `backups/pre-migration-<timestamp>.tar.gz` (une seule fois).
2. Patch `plugins/Multiverse-Core/worlds.yml` : `autoload: false` pour tous les mondes sauf `swr` (la map principale définie dans `server.properties` → `level-name=swr`). Idem `keepspawninmemory: false` pour libérer la RAM.
3. Patch `spigot.yml` : `bungeecord: false`. L'ancien serveur vivait derrière un BungeeCord en 2016, donc Spigot refuse par défaut les connexions directes avec :
   ```
   lost connection: If you wish to use IP forwarding, please enable it in your BungeeCord config as well!
   ```
   En mode migration on se connecte en direct → il faut désactiver ce flag.

> Les backups locaux `worlds.yml.bak` et `spigot.yml.bak` (si modifié) sont conservés côte-à-côte au cas où.

#### b. Lancer le serveur avec log fichier

```bash
cd mc-server-old/

# Vérifie WorldEdit
ls plugins/ | grep -i worldedit    # devrait afficher worldedit-bukkit-6.1.jar

# Java 8 obligatoire pour Spigot 1.8.x
sudo apt install openjdk-8-jre -y

# Démarre, redirige TOUT vers logs/migration.log (stderr+stdout)
mkdir -p logs
/usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx2G -jar spigot-1.8.7.jar nogui \
    2>&1 | tee logs/migration.log
```

`tee` te laisse lire en direct ET garde une copie propre du log sur disque (`mc-server-old/logs/migration.log`) que tu peux envoyer pour diagnostic.

> ⚠️ `UnsupportedClassVersionError` = ton JDK par défaut est trop récent. Utilise toujours le chemin absolu de Java 8.

#### c. Se connecter

**Le serveur écoute sur le port `12734`** (cf. `server.properties` → `server-port=12734`), **pas 25565**. Depuis ton client Minecraft Java :

- Version du client : **1.8.9** (la plus stable de la branche 1.8, compatible avec Spigot 1.8.7 via le protocole 47).
- Direct Connect : `localhost:12734` (ou `127.0.0.1:12734`).
- Si WSL2 depuis Windows : `localhost:12734` passe via le forwarding auto, sinon récupère l'IP WSL (`wsl hostname -I`) et tente `<IP-WSL>:12734`.

Si tu veux simplifier (et libérer 25565 pour ton nouveau serveur) : édite `server.properties` → `server-port=25565`. Pas obligatoire pour la migration.

#### d. Arrêter le serveur proprement

Spigot 1.8 **n'intercepte pas Ctrl+C** de façon fiable. Dans la console du serveur, tape :

```
stop
```

Si le terminal est vraiment coincé : depuis un second terminal, `ps aux | grep spigot` puis `kill <PID>` (pas `-9` en premier, essaie SIGTERM d'abord pour que les mondes se sauvent).

#### e. Lire les warnings sans paniquer

Deux familles de warnings qui **ne sont pas de la corruption** :

- `Attempted to place a tile entity (TileEntityCommand) at X,Y,Z (AIR) where there was no entity tile!` — des **command blocks orphelins** : le bloc a été remplacé par de l'air mais son tile entity est resté dans le .mca. Inoffensif. On peut les nettoyer plus tard avec MCAselector ou les ignorer.
- `Preparing spawn area for <world>` — pré-génération normale des chunks autour du spawn. Pas une régénération du monde.

Un seul warning est une **vraie** erreur dans tes logs actuels :

```
[ERROR]: [Multiverse-Core] The world 'build' could NOT be loaded because it contains errors!
```

→ Le monde `build` est effectivement corrompu (1 sur 43). Les autres sont accessibles. Stratégie : soit tu le laisses tomber, soit tu tentes un `mv repair build` ou [MCAselector](https://github.com/Querz/mcaselector) pour inspecter les `.mca` cassés.

### Étape 2 — Sauvegarder chaque construction en `.schematic`

Connecte-toi en OP sur le serveur 1.8 (normalement ton pseudo est déjà dans `ops.json` ou `ops.txt`).

> ⚠️ **Syntaxe WorldEdit 6.1 (Spigot 1.8.7) — piège important** : la commande est `//schem save <format> <nom>` (format **avant** nom), pas l'inverse. Le format à utiliser est `mce` (MCEdit legacy `.schematic`). Le flag `fast` **n'existe pas** en WE 6.1 — il a été introduit dans WE 7.x/FAWE. Si tu tapes `//schem save hub-skywars fast` sur ton vieux serveur, tu obtiens `Unknown schematic format: hub-skywars` parce que WE interprète `hub-skywars` comme un nom de format.
>
> **Règle mnémo pour ce serveur 1.8** : `//schem save mce <nom>` — et seulement ça.

Pour chaque zone à sauver (hub SkyWars, chaque map SkyWars, spawn, lobby, salon de jeux, survival games…) :

```
# Place-toi au coin 1 de la zone
//pos1

# Déplace-toi au coin opposé
//pos2

# Enregistre (le fichier part dans plugins/WorldEdit/schematics/)
//schem save mce <nom>

# Exemple — on préfixe par destination future sur le nouveau serveur :
//schem save mce hub-skywars          # le hub d'attente SkyWars → deviendra un coin du hub principal
//schem save mce sw-desert            # map SkyWars "desert"
//schem save mce sw-jungle            # map SkyWars "jungle"
//schem save mce sg-spawn             # spawn Survival Games
//schem save mce lobby-old            # l'ancien lobby 1.8 (pour référence / nostalgie)
```

Convention de nommage conseillée (elle nous sert ensuite au moment de l'import) :

- `hub-<zone>` → blocs destinés au nouveau `hub` (le lobby principal sur le serveur Purpur).
- `sw-<nom>` → map SkyWars individuelle.
- `sg-<nom>` → map Survival Games.
- `mg-<nom>` → mini-game générique (1v1, parkour, etc.).
- `old-<nom>` → archive brute, « tel quel en 2016 », qu'on ne retouchera pas.

**Option A — sélection par WorldGuard** : si tu avais des régions WorldGuard qui délimitent tes maps, tu peux cibler la région directement :

```
//rg lobby
//schem save mce hub-old
```

**Option B — sélection large** (si tu connais juste un block central) :

```
//pos1
//expand 200 up
//expand 200 down
//expand 200 north
//expand 200 south
//expand 200 east
//expand 200 west
//schem save mce zone-large
```

> 💡 `//schem` est l'alias de `//schematic` sur WE 6.1 — les deux marchent tant que la syntaxe `<format> <nom>` est respectée.

### Étape 3 — Copier les schematics hors du serveur 1.8

```bash
mkdir -p data/main/plugins/WorldEdit/schematics
cp mc-server-old/plugins/WorldEdit/schematics/*.schematic \
   data/main/plugins/WorldEdit/schematics/
```

> 💡 **Astuce** : si tu veux convertir `.schematic` (legacy) → `.schem` (moderne) avant import, utilise [MCEdit-Unified](https://github.com/Podshot/MCEdit-Unified/releases) ou [mcschematic-cli](https://github.com/ReierXGaming/mcschematic). WorldEdit 1.21 accepte les deux formats en lecture, mais écrit toujours en `.schem`.

### Étape 4 — Importer dans Paper 1.21

Démarre ton serveur principal :

```bash
make docker-up        # dev local
# ou
make up               # prod K3s
```

Connecte-toi en OP, prépare un monde vide (ou Multiverse crée un monde plat) :

```
/mv create hub normal -t FLAT
/mv tp hub
```

Puis charge et colle :

```
//schematic load hub-main
//paste -a
```

- `-a` : ignore les blocs d'air (garde le décor existant en dessous/autour)
- `-o` : colle à la position exacte d'origine (même X/Y/Z qu'en 1.8)
- Sans flag : colle à la position du joueur, bien aligner en `//pos1` d'abord

---

## Cas spéciaux

### Signes et têtes custom

WorldEdit conserve le **texte des signes** et les **skins des têtes** depuis la 1.13. En 1.8, c'est un peu aléatoire — teste sur une petite zone avant de tout valider.

Si des signes arrivent **vides** après migration : le format NBT a changé (ligne simple → JSON component). La solution rapide est un plugin type **EditSign** qui te laisse éditer en 1.21.

### Coffres remplis

Les items stockés en 1.8 (potions, enchantements) ont parfois des IDs obsolètes. WorldEdit essaye de convertir, mais certaines potions custom peuvent atterrir en `minecraft:water`. **Fais un test d'abord** sur un coffre connu.

### Spawners custom

Les spawners de mobs custom (avec monture, équipement) ont un format NBT qui a changé. Ils arriveront probablement **vides** et il faudra les re-configurer via le plugin [SilkSpawners](https://www.spigotmc.org/resources/silkspawners.5746/) ou équivalent.

### Commands blocks et redstone complexe

- Les **command blocks** contiennent souvent des commandes 1.8 obsolètes (`/tellraw`, sélecteurs `@p[r=10]`). À réécrire à la main.
- La **redstone** (pistons, comparateurs) est généralement compatible — mais teste les circuits critiques (portes secrètes, horloges).

---

## Plan recommandé pour MineShark

Ordre validé avec Alexis — **le hub (lobby) passe en premier** (objectif : le déployer comme map principale sur le VPS rapidement).

Convention de nommage côté cible 1.21 : le monde lobby s'appelle `hub`, le monde survie s'appelle `main`. Côté ancien serveur 1.8 on garde les noms d'origine sur disque (`lobby`, `lobbyswr`, `spawn`…) — on renomme au moment du paste.

1. **Reset propre** : `make old-server-reset` → `make old-server-prep` (repart du zip, patche les configs).
2. **Première session d'export — le hub uniquement** :
   - `make old-server-run` → connexion `localhost:12734` avec un client **MC 1.8.9**.
   - `/mv load lobby` (et `/mv load lobbyswr`, `/mv load spawn` — identifier visuellement celui qui est LE lobby principal).
   - `/mv tp lobby` puis `//pos1` / `//pos2` sur la zone construite → `//schem save hub-main fast`.
   - `stop` dans la console.
3. **Deploy du hub sur le VPS** :
   - Copier `mc-server-old/plugins/WorldEdit/schematics/hub-main.schematic` → `data/main/plugins/WorldEdit/schematics/`.
   - `make deploy` (push + pull + `make re` sur le VPS).
   - En jeu (OP) : `/mv create hub normal -t FLAT` → `/mv tp hub` → `//schem load hub-main` → `//paste -a`.
   - Définir hub comme spawn par défaut (`/mv setspawn`, `/mvs default hub` côté portail Multiverse).
4. **Inventaire des autres zones** — 42 mondes non corrompus (tout sauf `build`). Faire une liste ordonnée par importance (SkyWars → SurvivalGames → maps créatives).
5. **Sessions d'export suivantes** : lancer 1.8, `/mv load <map>`, `//schem save <nom> fast`, passer à la suivante. Tu peux rester plusieurs heures connecté pour tout sauver d'un coup.
6. **Backup schematics** : `tar czf backups/schematics-$(date +%F).tar.gz data/main/plugins/WorldEdit/schematics/` — tu peux archiver hors repo aussi (Drive, disque externe).
7. **Import progressif en prod** : une map à la fois, test en jeu, fix des signes/coffres si besoin.
8. **Archive finale de `mc-server-old/`** : une fois tout récupéré, `tar czf mc-server-old.tar.gz mc-server-old/` et sortir du repo pour libérer l'espace. Le zip de référence reste comme fallback.

---

## Alternative : Chunker (outil web)

[Chunker](https://chunker.app/) (développé par Hive) est un **convertisseur automatique** en ligne : tu uploades ton monde 1.8, il te renvoie un monde 1.21 avec conversion des blocs. C'est rapide mais :
- ⚠️ il ne récupère PAS les signes custom ni les têtes de joueur fidèlement,
- ⚠️ la conversion des biomes produit parfois des transitions abruptes,
- ⚠️ taille du monde limitée à ~2 Go en version gratuite.

**Quand utiliser Chunker plutôt que WorldEdit** : quand tu veux **tout le monde** (terrain, générique) et pas juste les constructions. Pour MineShark, on veut les **builds** uniquement → WorldEdit est mieux adapté.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Could not load schematic` au `//schem load` | Fichier `.schematic` (legacy) sur WorldEdit récent qui ne veut plus les lire | Convertir en `.schem` via MCEdit-Unified |
| Blocs manquants après paste (air à la place) | Block ID 1.8 sans équivalent moderne | Chercher manuellement dans le schematic, les remplacer en 1.21 |
| Signes vides | Conversion NBT incomplète | Les réécrire, ou plugin de conversion type [SignConverter](https://www.spigotmc.org/resources/signconverter.56823/) |
| Crash au paste sur gros schematic | Pas assez de RAM ou trop de blocs d'un coup | Découper en zones et paste morceau par morceau |
| Orientation cassée (escaliers à l'envers) | Rare mais possible sur portes et escaliers rotatifs | `//rotate 90` puis re-paste |

---

## Références

- Documentation WorldEdit officielle : https://worldedit.enginehub.org/en/latest/usage/clipboard/
- Format .schem (Sponge) : https://github.com/SpongePowered/Schematic-Specification
- Chunker : https://learn.microsoft.com/en-us/minecraft/creator/documents/chunkeroverview
