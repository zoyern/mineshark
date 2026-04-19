# `plugins/manual/` — workflow "drop le jar"

Dossier pour tous les plugins **qu'on ne peut pas** tirer via les
mécanismes automatiques du serveur principal :

| Mécanisme auto | Pour quoi | Dans quel fichier |
|---|---|---|
| `MODRINTH_PROJECTS` | plugins libres sur modrinth.com | `.env` → `PLUGINS_MODRINTH` |
| `SPIGET_RESOURCES` | plugins free/libres sur spigotmc.org | `.env` → `PLUGINS_SPIGET` |
| `PLUGINS` (URL) | releases GitHub, builds CI publics | `k8s/main/deployment.yaml` |
| **`plugins/manual/`** | plugins "Bukkit classiques" — BuiltByBit payants, disparus, jars custom, versions pinnées | **ici (ce dossier)** |
| **`plugins/manual/bentobox-addons/`** | addons BentoBox (AOneBlock, Level, etc.) — PAS des plugins Bukkit, iront dans `/data/plugins/BentoBox/addons/` | **sous-dossier dédié** |

## Cas d'usage typiques

- Plugin **payant BuiltByBit / Polymart** (distribué avec licence, pas
  d'URL publique directe).
- Plugin **disparu** du marketplace qu'on avait sauvegardé (ex. OITC
  d'époque).
- **Jar custom** qu'on a compilé nous-même.
- Plugin qu'on veut **pinner à une version précise** plus ancienne que
  ce que Spiget sert par défaut.

## Workflow complet

```
[dev local]                     [VPS]                   [pod mc-main]
────────────                    ──────                  ─────────────
plugins/manual/monjar.jar
         │
         │   make plugins-sync
         ▼                      /var/lib/mineshark/
                                  manual-plugins/
                                    monjar.jar
                                        │
                                        │  rollout restart
                                        ▼
                                                      initContainer
                                                       copy-manual-plugins
                                                           │
                                                           ▼
                                                      /data/plugins/
                                                        monjar.jar
                                                        (autres jars
                                                         MODRINTH/SPIGET
                                                         téléchargés)

plugins/manual/bentobox-addons/AOneBlock-1.23.0.jar
         │
         │   make plugins-sync (même target)
         ▼                      /var/lib/mineshark/
                                  manual-bentobox-addons/
                                    AOneBlock-1.23.0.jar
                                        │
                                        │  rollout restart
                                        ▼
                                                      initContainer
                                                       copy-manual-plugins
                                                         (2e étape)
                                                           │
                                                           ▼
                                                      /data/plugins/BentoBox/
                                                        addons/
                                                          AOneBlock-1.23.0.jar
```

## Comment ajouter un jar

1. **Dépose le `.jar`** dans ce dossier (`plugins/manual/`).
2. **Commite-le** si tu veux le versionner :
   ```
   git add plugins/manual/monjar.jar plugins/manual/*.jar
   git commit -m "plugins/manual: ajout monjar vX.Y.Z"
   ```
   (Le `.gitignore` racine contient `!plugins/manual/*.jar`, donc les
   jars de ce dossier **ne sont pas ignorés** — contrairement au reste
   du repo où `*.jar` est banni.)
3. **Synchronise sur le VPS** :
   ```
   make plugins-sync
   ```
   Cette cible :
   - rsync `plugins/manual/*.jar` → `/var/lib/mineshark/manual-plugins/`
     sur le VPS (via SSH, idempotent) ;
   - `kubectl rollout restart deploy/mc-main` pour que l'initContainer
     re-copie les jars dans `/data/plugins/` au prochain boot.
4. **Attends ~90 s** le redémarrage puis vérifie :
   ```
   make logs                 # watch les lignes "Loaded MonPlugin"
   make rcon CMD=plugins     # liste des plugins chargés
   ```

## Cas particulier — addons BentoBox

BentoBox est installé automatiquement via Spiget (ID 73261). **Ses addons**
(AOneBlock, Level, BSkyBlock, etc.) ne sont PAS des plugins Bukkit et
doivent aller dans `plugins/BentoBox/addons/` du pod, sinon BentoBox les
ignore silencieusement.

Workflow :

1. Télécharge le jar de l'addon depuis les releases GitHub du projet
   BentoBoxWorld (ex. `https://github.com/BentoBoxWorld/AOneBlock/releases`).
2. Dépose-le dans **`plugins/manual/bentobox-addons/`** (PAS dans
   `plugins/manual/` directement).
3. `make plugins-sync` (la cible gère les deux dossiers d'un coup).
4. Vérifie après redémarrage :
   ```
   make rcon CMD="bentobox version"
   make rcon CMD="bentobox catalog"
   ```
   L'addon doit apparaître dans la liste et être `enabled`.

Compatibilité : toujours prendre la version de l'addon **compilée pour la
même major de BentoBox** que celle téléchargée par Spiget (ID 73261). Les
releases BentoBoxWorld indiquent la compat en tête de changelog.

## Comment supprimer un jar

1. `rm plugins/manual/monjar.jar` (puis commit).
2. **Attention** : `make plugins-sync` utilise `rsync --delete` sur
   `/var/lib/mineshark/manual-plugins/` → le jar est retiré du VPS.
3. Mais le jar est DÉJÀ présent dans `/data/plugins/` du PVC → il y
   restera. Pour le purger vraiment :
   ```
   kubectl -n mineshark exec deploy/mc-main -- rm /data/plugins/monjar.jar
   make restart-main
   ```

## Précautions

- **Licences** : si le plugin est payant, vérifie que sa licence
  autorise le stockage dans un repo privé / le déploiement sur un
  serveur privé. La plupart des plugins BuiltByBit l'autorisent ;
  certaines licences custom (ex. single-server) non.
- **Ne jamais committer de licence/clé d'activation** dans ce dossier.
  Si un plugin nécessite une clé, stocker la clé dans un Secret K8s
  séparé (voir `k8s/secrets.yaml`).
- **Taille** : garder les jars < 5 MB idéalement. GitHub refuse > 100 MB,
  et le VPS n'aime pas les rsync lourds en continu.
- **Conflits de noms** : le initContainer copie `*.jar` en écrasant →
  si Spiget télécharge `FooPlugin-1.2.jar` et qu'on a ici
  `FooPlugin-1.2.jar`, le manuel gagne. Utile pour pinner une version.

## Diagnostic

**Le jar n'apparaît pas dans `/plugins` RCON après sync** :

```
# 1) Le jar est-il bien sur le VPS ?
make ssh
ls -la /var/lib/mineshark/manual-plugins/

# 2) L'initContainer l'a-t-il copié ?
kubectl -n mineshark logs deploy/mc-main -c copy-manual-plugins

# 3) Est-il dans /data/plugins/ du pod ?
kubectl -n mineshark exec deploy/mc-main -c minecraft -- ls -la /data/plugins/

# 4) Paper l'a-t-il chargé ?
kubectl -n mineshark logs deploy/mc-main -c minecraft | grep -i monjar
```

Cause la plus fréquente : jar compilé pour une mauvaise version
Minecraft ou Java. Vérifier le `plugin.yml` du jar :
```
unzip -p monjar.jar plugin.yml
```
Le champ `api-version` doit être ≤ 1.21 et compatible avec Paper 1.21.8.
