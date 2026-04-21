# Bridge Discord ↔ serveur moddé

Le serveur moddé MineShark embarque `discord-chat-mod` (Modrinth,
maintenu par *denisnumb*) pour relier le tchat in-game à un salon
Discord. Le mod est injecté sur **tous** les modpacks via
`MODRINTH_PROJECTS` dans `k8s/mod/deployment.yaml` — tu n'as pas à
le ré-installer quand tu changes de pack.

---

## Ce que fait le mod

- Tout message envoyé dans le tchat MC apparaît dans le salon Discord configuré.
- Tout message posté dans ce salon Discord apparaît en jeu (préfixé du pseudo Discord).
- Events joueurs : connexion, déconnexion, mort.
- Commande `/discord` in-game pour tester.

---

## Setup — une fois, 5 minutes

### 1. Créer l'application bot

1. Va sur <https://discord.com/developers/applications> → **New Application** → nomme-la (ex. "MineShark Bridge").
2. Onglet **Bot** → **Reset Token** → copie la valeur (tu ne la reverras plus).
3. Dans le même onglet, active les trois **Privileged Gateway Intents** :
   - Presence Intent
   - Server Members Intent
   - Message Content Intent

### 2. Inviter le bot sur ton serveur Discord

1. Onglet **OAuth2** → **URL Generator**.
2. Scopes : `bot`.
3. Permissions : `View Channels`, `Send Messages`, `Read Message History`, `Embed Links`, `Manage Webhooks`.
4. Ouvre l'URL générée dans un navigateur, sélectionne ton serveur, valide.

### 3. Récupérer les IDs Discord

1. Discord → Paramètres utilisateur → **Avancés** → active **Mode développeur**.
2. Clic-droit sur ton serveur → **Copier l'identifiant du serveur** → c'est ton `guildId`.
3. Clic-droit sur le salon dédié au bridge → **Copier l'identifiant** → c'est ton `channelId`.

### 4. Renseigner `.env`

```bash
DISCORD_TOKEN=ton-token-bot-ici
DISCORD_GUILD_ID=123456789012345678
DISCORD_CHANNEL_ID=123456789012345678
```

> ⚠️ `.env` est gitignored. Ne committe **jamais** ces valeurs.

### 5. Appliquer

> **⚠️ Lance ces 3 commandes depuis TA MACHINE LOCALE** (WSL/Mac), pas sur
> le VPS. Elles encapsulent du `ssh` en interne et lisent les variables
> `DISCORD_*` depuis ton `.env` local. Pas besoin d'avoir `kubectl`
> installé côté WSL.

```bash
# Depuis LOCAL (racine du repo) :
make discord-setup     # lit .env local → SSH → crée le Secret K8s + rollout mc-mod
make discord-status    # SSH → tail des logs mc-mod (filtre JDA / discord_chat_mod)
```

Si tout va bien, tu dois voir dans les logs :

```
[discord_chat_mod] JDA ... Finished Loading!
```

Test rapide :

```bash
make discord-test      # SSH → RCON `say [TEST] MineShark → Discord` sur mc-mod
```

> Besoin de propager aussi d'autres variables `.env` (CF_API_KEY, slug
> modpack, etc.) sur le VPS ? Voir `make env-sync` (scp avec diff preview +
> confirmation). `make discord-setup` lui ne pousse QUE le Secret Discord,
> pas le fichier `.env` en entier.

---

## Architecture technique

```
┌─ LOCAL (WSL / Mac) ─────────────────────────────────────────────┐
│  .env  (DISCORD_TOKEN / DISCORD_GUILD_ID / DISCORD_CHANNEL_ID)   │
│  k8s/mod/discord_chat_mod-common.toml.tpl   (template commit)    │
│    │                                                             │
│    │  make discord-setup                                         │
│    │    1. sed @@DISCORD_TOKEN@@ etc. → fichier temp local      │
│    │    2. ssh VPS → kubectl create secret generic …            │
│    │       --from-file=discord_chat_mod-common.toml=/dev/stdin  │
│    ▼                                                             │
│  ssh -p $VPS_SSH_PORT $VPS_USER@$VPS_IP ' kubectl apply -f - '  │
└──────────────────────────┬──────────────────────────────────────┘
                           │  SSH (stdin = TOML rendu)
                           ▼
┌─ VPS (K3s) ─────────────────────────────────────────────────────┐
│  Secret K8s `discord-chat-mod-toml`                              │
│      key = discord_chat_mod-common.toml                          │
│      value = contenu TOML complet (token, guildId, channelId)    │
│      │                                                           │
│      ▼  monté UNIQUEMENT dans l'initContainer                    │
│  initContainer `discord-toml-install` (busybox)                  │
│      cp -f /discord-toml/…  →  /data/config/…   (PVC, RW)        │
│      │                                                           │
│      ▼  container principal démarre ensuite                      │
│  /data/config/discord_chat_mod-common.toml   (dans le PVC, RW)   │
│      │      le mod peut lire ET écrire (autosave night-config)   │
│      ▼  lecture au démarrage du mod                              │
│  JDA (lib Discord) ──────────────────────────►  salon Discord    │
└─────────────────────────────────────────────────────────────────┘
```

**Points clés :**

- Les cibles `make discord-*` tournent **depuis ta machine locale** et
  appellent `kubectl` à distance via SSH (cf. `make/admin.mk`). Tu n'as
  donc rien à installer côté WSL à part `ssh` et `make`.
- Le `.env` local reste source de vérité : pas besoin de le copier sur
  le VPS (le Secret K8s suffit). Si tu veux tout de même propager
  d'autres variables (`CF_API_KEY`, modpack, etc.), `make env-sync`
  fait un `scp` avec diff preview.
- Le Secret K8s survit à `make mod-reset` (supprime seulement le PVC).
- L'initContainer **re-copie** le TOML canonique du Secret vers le PVC
  à CHAQUE boot du pod → valeurs du `.env` ré-injectées de façon
  idempotente. Si un rewrite NeoForge ou un autosave du mod bouffe
  des champs, le boot suivant les restaure.
- Le container principal voit le fichier en **lecture/écriture** (PVC
  normal). C'est nécessaire parce que `discord-chat-mod` v2.6.2 fait
  lui-même un autosave au load (`ConfigManager.removeDeprecatedParameters`
  → `AutosaveCommentedFileConfig.remove()`). Sans RW, crash au boot.
- Le template `k8s/mod/discord_chat_mod-common.toml.tpl` est versionné
  dans le repo. Pour éditer d'autres champs TOML (`serverLogsChannelId`,
  `enableMinecraftChatCustomization`, etc.), tu modifies ce template
  puis `make discord-setup` régénère le Secret avec les nouvelles valeurs.

### Piège `CF_OVERRIDES_EXCLUSIONS` (overrides du modpack vs. TOML pré-injecté)

Si ton modpack CurseForge contient un `config/discord_chat_mod-common.toml`
dans ses *overrides* (c'est le cas de **Modded Together** et d'autres packs
qui embarquent la config du bridge par défaut), au boot `mc-image-helper`
extrait le zip et tente de copier ce fichier par-dessus celui que notre
initContainer vient d'injecter. Résultat : notre token canonique est
écrasé par la version vide du pack → JDA throw `Token may not be empty`
au load du mod.

**Fix** : `CF_OVERRIDES_EXCLUSIONS=config/discord_chat_mod-common.toml` dans
`k8s/mod/deployment.yaml`. Itzg skip ce fichier lors de l'application des
overrides, notre version reste intacte. Déjà appliqué dans le repo, à ne
jamais retirer tant qu'on utilise cette archi.

### Historique — 3 itérations avant de converger (2026-04-21)

**V1 — initContainer `busybox + sed` sur PVC RW**

Un initContainer patchait 3 lignes du TOML à chaque boot (token, guildId,
defaultChannelId), à partir d'un Secret à 3 literal keys. Comportement observé :

1. L'initContainer patchait correctement le fichier (vérif `grep` OK).
2. Le container principal démarrait, NeoForge chargeait sa config.
3. **~30-40 s après le start**, NeoForge (ou le mod) normalisait le TOML
   et réécrivait le fichier, resettant les 3 valeurs à `""`.
4. JDA partait avec un token vide → `Token may not be empty`.

Hypothèse : l'indent TAB natif du TOML du mod vs. les 8 espaces introduits
par busybox `sed` → format non-canonique → reset aux defaults. Non vérifié
à 100 % car on a pivoté direct vers V2.

**V2 — Secret monté en subPath READ-ONLY**

Template complet commité, Secret à 1 clef (le TOML entier rendu), `mount subPath
readOnly: true` + `defaultMode: 0444`. NeoForge ne peut plus réécrire → token
persiste. Problème :

```
FileSystemException: config/discord_chat_mod-common.toml: Read-only file system
  at com.shadow.com.electronwill.nightconfig.core.io.WritingMode$2.open
  at ...ConfigManager.removeDeprecatedParameters(ConfigManager.java:47)
  at ...DiscordChatModNeoForge.<init>(DiscordChatModNeoForge.java:37)
```

`discord-chat-mod` v2.6.2 fait lui-même un autosave au load via
`AutosaveCommentedFileConfig.remove()` (lib `night-config`) pour purger les
clefs dépréciées. Le mount Secret K8s étant readOnly au niveau kernel
(tmpfs bind-mount), aucune écriture n'est possible → crash `Read-only file
system`. Retirer `readOnly: true` du mount spec ne résout pas : c'est le
backend qui est readOnly.

Collatéral V2 : le modpack Modded Together embarque `discord_chat_mod-common.toml`
dans ses overrides → `mc-image-helper` tentait `Files.copy()` par-dessus →
`Device or resource busy`. Fix : `CF_OVERRIDES_EXCLUSIONS` (gardé en V3).

Collatéral V2 bis : la manifeste persistent itzg (`/data/.curseforge-manifest.json`)
conservait l'entrée du TOML → au boot suivant, `Manifests.cleanup` tentait
`deleteIfExists()` sur notre mount readOnly → `Device or resource busy`.
Fix : pod one-shot pour purger `.curseforge-manifest.json` et `.modrinth-manifest.json`
du PVC. Si tu re-migres un jour et que ça re-casse, c'est le pattern à reprendre.

**V3 (actuelle) — initContainer copie Secret → PVC, container principal en RW**

L'initContainer `discord-toml-install` (busybox) copie à chaque boot le TOML
canonique du Secret vers `/data/config/discord_chat_mod-common.toml` dans le
PVC. Le container principal le voit en **lecture/écriture** → l'autosave du
mod fonctionne. Les valeurs canoniques sont ré-injectées au prochain boot si
jamais un rewrite les modifiait. Le template étant en indent TAB (format
canonique du mod), le risque "NeoForge rewrite + reset" observé en V1 est
faible — et même s'il se déclenchait, la canonisation initContainer au boot
suivant le ré-annulerait.

---

## Dépannage

### Le bot ne se connecte pas

```bash
make discord-status
```

| Ce que tu vois dans les logs            | Cause probable                  | Fix |
|-----------------------------------------|---------------------------------|-----|
| `Token may not be empty`                | Secret pas injecté              | `make discord-setup` |
| `Invalid token`                         | Token obsolète ou mal copié     | Reset token sur le portail Developer, mets à jour `.env`, `make discord-setup` |
| `Missing Access` (guild introuvable)    | Bot pas invité sur le serveur   | Refais l'étape 2, puis `make discord-setup` |
| `Unknown Channel`                       | Mauvais `DISCORD_CHANNEL_ID`    | Re-copie l'ID du salon, `make discord-setup` |
| `JDA ... Finished Loading!`             | **OK**, bot connecté            | — |

### Les messages Discord n'apparaissent pas en jeu

- Vérifie que les 3 intents privilégiés sont activés (étape 1.3).
- Le bot doit avoir accès au salon : clic-droit salon → *Modifier* → *Permissions* → ajoute le bot avec "Lire les messages" + "Voir le salon".

### Je veux changer de salon Discord

1. Édite `DISCORD_CHANNEL_ID` dans `.env`.
2. `make discord-setup`.
3. Le Secret K8s est régénéré à partir du template, le pod redémarre, le nouveau TOML est monté en read-only, le bot pointe vers le nouveau salon.

### Je veux désactiver temporairement le bridge

Le plus simple : `make discord-teardown` (depuis LOCAL). Ça supprime le Secret `discord-chat-mod-toml` (et l'ancien `discord-chat-mod-config` s'il traîne) puis restart mc-mod.

> ⚠️ **Attention** : sans le Secret, le mount readOnly ne peut plus se monter
> et le pod mc-mod restera bloqué en `ContainerCreating`. Deux options :
>
> 1. **Désactiver temporairement l'injection du mod** : retire
>    `discord-chat-connect` de `MODRINTH_PROJECTS` dans
>    `k8s/mod/deployment.yaml` puis `make deploy`. Le mod n'est plus chargé,
>    le volume n'est plus nécessaire côté config (mais le `volumeMount`
>    reste déclaré dans le Deployment → retire-le aussi, ou simplement
>    laisse le Secret en place avec des valeurs factices).
> 2. **Garder le Secret avec un token factice** : mets `DISCORD_TOKEN=disabled`
>    dans `.env`, `make discord-setup`. Le mod démarre, JDA échoue avec
>    `Invalid token` (WARN non bloquant), le serveur tourne normalement.

Le path n°2 est généralement le moins intrusif.

### Un token a fuité (log, capture, commit accidentel)

1. **Immédiatement** : <https://discord.com/developers/applications> → ton app → Bot → **Reset Token**.
2. Colle le nouveau token dans `.env`.
3. `make discord-setup`.
4. Si tu as committé le token dans Git : purge l'historique avec `git filter-repo` (le simple `git rm` ne suffit pas, le token reste visible dans l'historique public).

---

## Cibles Make

| Commande                 | Exécutée depuis | Rôle                                                                 |
|--------------------------|-----------------|----------------------------------------------------------------------|
| `make secrets`           | VPS             | Crée les Secrets K8s **non-Discord** (RCON, CF_API_KEY, Velocity forwarding). Appelé par `make up`. **Ne crée PAS** `discord-chat-mod-toml` — le TOML doit être rendu depuis un `.env` local → voir `make discord-setup`. |
| `make discord-setup`     | **LOCAL**       | Rendu local du template `k8s/mod/discord_chat_mod-common.toml.tpl` via `sed` (substitue `@@DISCORD_*@@`) → SSH → `kubectl create secret discord-chat-mod-toml` (`--from-file`) → rollout mc-mod. À lancer après modif des `DISCORD_*` dans `.env` ou du template. |
| `make discord-teardown`  | **LOCAL**       | SSH → supprime les Secrets `discord-chat-mod-{config,toml}` (ancien + nouveau). Rotation ou désactivation complète. |
| `make discord-status`    | **LOCAL**       | SSH → tail des logs mc-mod filtré JDA / discord_chat_mod.            |
| `make discord-test`      | **LOCAL**       | SSH → RCON `say [TEST] MineShark → Discord`. Doit apparaître dans le salon Discord.  |
| `make env-sync`          | **LOCAL**       | Propage le `.env` entier (pas que Discord) sur le VPS via scp, avec diff preview + confirmation. Utile après un changement de `CF_API_KEY`, `MODPACK_SLUG`, etc. |
| `make doctor`            | LOCAL           | Rappelle si le bridge est configuré ou non (non bloquant). Détecte aussi `VPS_IP=127.0.0.1` (placeholder du repo public). |

> **Récap "où je lance quoi ?"** — les cibles `make discord-*` tournent
> depuis **ta zsh locale**. Elles ne nécessitent pas que tu sois connecté
> au VPS : elles font le SSH elles-mêmes. Tu n'as donc aucune raison de
> faire `make ssh` d'abord puis `make discord-setup` dessus — ce serait
> une double indirection qui ne marcherait d'ailleurs pas (le VPS n'a pas
> le `.env` du repo local).

---

## Pourquoi un Secret monté readOnly et pas une ConfigMap ?

- Le TOML contient le **token Discord** : c'est un credential. Une
  **ConfigMap** ne chiffre pas au repos et s'affiche en clair via
  `kubectl describe configmap`. Un **Secret** est stocké base64 (avec
  chiffrement activable via `--encryption-provider-config` côté etcd)
  et masqué par défaut (`kubectl get secret -o yaml` le montre, mais
  `describe` non).
- Le mod lit un **fichier TOML sur le disque**, pas des variables
  d'environnement — il faut donc lui fournir un fichier, pas des envs.
- Le **mount readOnly** (via `subPath` + `defaultMode: 0444`) empêche
  NeoForge de réécrire le fichier au boot (cf. *Historique* plus haut).
  C'est le point critique qui distingue cette archi de la précédente
  (initContainer + sed sur PVC en RW).
- Le template complet `discord_chat_mod-common.toml.tpl` (415 lignes)
  est **versionné dans le repo** : pour ajouter des custom commands ou
  activer `enableMinecraftChatCustomization`, tu édites le template, tu
  commit, puis `make discord-setup` régénère le Secret. Pas besoin de
  toucher au cluster.
