# Cleanup manuel — à faire côté Windows

Ce document liste les choses qui doivent être nettoyées **depuis l'Explorateur Windows** (pas depuis Cowork ou WSL) parce que le mount FUSE virtiofs refuse certaines opérations destructives (unlink/rename/rm).

Symptôme qu'on voit depuis Cowork : `stat` voit le dossier, mais `rm -rf`, `mv`, Python `shutil.rmtree` échouent tous en `Operation not permitted` ou `No such file or directory`. Rien de cassé côté contenu — c'est juste la couche de mount qui ne laisse pas passer la commande. Windows natif, lui, n'a pas ce problème.

## 1. Ghost directory `mc-server-old/`

Après un `make old-server-reset` qui a mal tourné le 2026-04-17, le dossier `mc-server-old/` est dans un état inconsistant :

- `stat mc-server-old` dit qu'il existe (inode valide, 4096 octets).
- `ls mc-server-old/` ne retourne rien.
- Tout `rm -rf`, `mv`, `rmdir` depuis WSL/Cowork échoue.

### Procédure

1. Ouvrir l'Explorateur Windows sur `C:\...\mineshark` (le chemin où tu as cloné le repo côté Windows).
2. Clic droit sur `mc-server-old` → Supprimer (Maj+Suppr pour skip la corbeille, sinon clic simple).
3. Ouvrir une console WSL :

```bash
cd ~/mineshark  # ou le chemin correct
ls mc-server-old 2>&1   # doit dire "No such file or directory" — parfait
```

Si Windows lui aussi refuse de supprimer (rare) : redémarre WSL (`wsl --shutdown` depuis PowerShell admin), puis réessaie.

## 2. Fichiers parasites à la racine (résidus de l'extraction buggée)

Quand le zip `mc-server-old-backup.zip` a été extrait avec un mauvais layout, ses fichiers se sont retrouvés **à la racine du repo**. Ce sont tous des artefacts de l'ancien Spigot 1.8.7 qui n'ont rien à faire dans le repo MineShark.

### Ce qu'il faut supprimer à la racine du repo

**Dossiers (tous d'origine 2015-2016)** :

```
MapSkyblock/        Mapa/             Monde/              SalonJeux/
SgSpawn/            Skuly/            Spawn/              SpawnSg/
SurvivalGames4/     YourMap/          build/              caves_1/
flatroom/           forest_4/         hotairballoons_5/   hougo/
jungle_2/           jungle_6/         lobby/              lobbyswr/
logs/               mondeswr/         pirates_3/          plugins/
spawnskywars/       sw1/ sw2/ sw3/ sw4/ sw5/ sw6/ sw7/ sw8/ sw9/
swr/                world/            world_nether/       world_the_end/
skyworld/           bone_7/
```

**Fichiers de config Minecraft 1.8 à la racine** :

```
.bashrc             .oracle_jre_usage/  .profile
banned-ips.json     banned-players.json  bukkit.yml       commands.yml
eula.txt            help.yml            ops.json           permissions.yml
pex.yml             server.properties   spigot-1.8.7.jar   spigot.yml
usercache.json      whitelist.json      worlds.yml         wepif.yml
addidsgriefprevention  easypex           globalgroupmanager
gpflags             gpfvault            help.yml           paper.yml
"Plugins 1v1 Skulycube beta 1.jar"
scriptblockplus/    api/
```

Bref : si c'est à la racine et que ça n'a PAS été créé par toi + moi cette semaine, à poubelle.

### Ce qu'il NE faut PAS supprimer (les vrais fichiers projet)

```
.git/           .github/           .env           .env.example
.gitignore      MEMORY.md          Makefile       README.md
config/         data/              backups/       docker-compose.yml
docker-compose.override.yml        docs/          k8s/           make/
scripts/        mc-server-old-backup.zip         docker-compose.mod.yml
```

Et tous les sous-dossiers de `config/`, `docs/`, `k8s/`, `make/`, `scripts/`.

### Procédure recommandée

Le plus rapide : un tri manuel dans l'Explorateur Windows, case par case. Mais pour accélérer, depuis PowerShell (sans risque — on liste d'abord, on supprime ensuite) :

```powershell
# Dans PowerShell, à la racine du repo :
cd C:\Users\<toi>\path\to\mineshark

# 1. Liste les dossiers à virer (vérifie visuellement avant la suite) :
$garbage = @(
  'MapSkyblock','Mapa','Monde','SalonJeux','SgSpawn','Skuly','Spawn','SpawnSg',
  'SurvivalGames4','YourMap','build','caves_1','flatroom','forest_4',
  'hotairballoons_5','hougo','jungle_2','jungle_6','lobby','lobbyswr','logs',
  'mondeswr','pirates_3','plugins','spawnskywars','sw1','sw2','sw3','sw4','sw5',
  'sw6','sw7','sw8','sw9','swr','world','world_nether','world_the_end',
  'skyworld','bone_7','scriptblockplus','api','.oracle_jre_usage'
)
$garbage | ForEach-Object { if (Test-Path $_) { "A supprimer : $_" } }

# 2. Si la liste te paraît correcte → supprime :
$garbage | ForEach-Object { Remove-Item -Recurse -Force $_ -ErrorAction SilentlyContinue }

# 3. Fichiers plats à supprimer :
$files = @(
  '.bashrc','.profile','banned-ips.json','banned-players.json','bukkit.yml',
  'commands.yml','eula.txt','help.yml','ops.json','permissions.yml','pex.yml',
  'server.properties','spigot-1.8.7.jar','spigot.yml','usercache.json',
  'whitelist.json','worlds.yml','wepif.yml','addidsgriefprevention','easypex',
  'globalgroupmanager','gpflags','gpfvault','paper.yml',
  'Plugins 1v1 Skulycube beta 1.jar'
)
$files | ForEach-Object { if (Test-Path $_) { Remove-Item -Force $_ } }
```

Puis côté WSL/Cowork :

```bash
git status    # doit redevenir propre (juste les fichiers qu'on a modifiés)
```

## 3. Supprimer `.env.ci`

Même histoire : virtiofs refuse l'unlink côté sandbox, même si le fichier est marqué comme déprécié. Depuis l'Explorateur Windows :

1. Clic droit sur `.env.ci` à la racine → Supprimer.
2. Vérifier côté WSL : `ls .env.ci 2>&1` doit dire "No such file or directory".

Le `.gitignore` inclut déjà `.env.ci` donc si le fichier revient un jour, il ne sera pas commité.

## 4. Vérification finale

Après nettoyage, cette commande doit retourner une liste courte (~20 items) :

```bash
ls -A | wc -l    # cible ≤ 25
```

Puis :

```bash
git status       # juste les fichiers que tu t'apprêtes à committer
make ci-lint     # doit passer (yamllint + compose config + kubectl dry-run + shellcheck)
```

Si les deux sont verts, le repo est prêt pour un commit propre.

## Pourquoi ça s'est passé

Le `make old-server-reset` d'origine supposait que `mc-server-old-backup.zip` contenait un dossier `mc-server-old/` à sa racine. Or le zip qu'on a reçu contient directement les fichiers à la racine du zip (pas de dossier parent). Résultat : `unzip -d mc-server-old` a créé un dossier vide `mc-server-old/` et a extrait tout à côté.

**Correctif appliqué** : `make/admin.mk:old-server-reset` détecte maintenant le layout du zip via `unzip -Z1 ... | head -1` et extrait correctement dans les deux cas. Cf. MEMORY.md § "Ancien serveur".

## Une fois le cleanup fait

- Reboot Cowork / rouvre la session → l'état ghost disparaît.
- `make old-server-reset` peut être relancé en toute sécurité (il va créer un `mc-server-old/` proprement depuis le zip).
- `make old-server-prep` puis `make old-server-run` → serveur 1.8 migrable.
- Priorité Alexis : export schematic du lobby, puis import sur le serveur Purpur 1.21.4.
