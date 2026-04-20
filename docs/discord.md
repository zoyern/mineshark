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

```bash
make discord-setup     # crée le Secret K8s + rollout mc-mod
make discord-status    # vérifie la connexion dans les logs
```

Si tout va bien, tu dois voir dans les logs :

```
[discord_chat_mod] JDA ... Finished Loading!
```

Test rapide :

```bash
make discord-test      # envoie "[TEST] MineShark → Discord" via RCON
```

---

## Architecture technique

```
.env (DISCORD_TOKEN / DISCORD_GUILD_ID / DISCORD_CHANNEL_ID)
    │
    ▼   make secrets  (ou make discord-setup)
Secret K8s `discord-chat-mod-config`
    │
    ▼   au boot du pod mc-mod
initContainer `discord-config-patch` (busybox + sed)
    │
    ▼
/data/config/discord_chat_mod-common.toml  (dans le PVC)
    │
    ▼   lecture au démarrage du mod
JDA (lib Discord) → salon Discord
```

**Points clés :**

- Le Secret K8s survit à `make mod-reset` (supprime seulement le PVC).
- L'initContainer patche le fichier TOML à *chaque* boot → pas de dérive entre Secret et config.
- Si le fichier TOML n'existe pas encore (1er boot vierge), l'initContainer skip proprement, le mod le crée à sa valeur par défaut, et le 2ᵉ restart applique le patch.
- Les autres champs du TOML (`serverLogsChannelId`, `use_language`, etc.) ne sont **pas** touchés — tu peux les éditer directement dans le pod via `kubectl exec` si besoin.

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
3. Le pod redémarre, l'initContainer repatche le TOML, le bot pointe vers le nouveau salon.

### Je veux désactiver temporairement le bridge

Vide les trois variables dans `.env` puis `make discord-setup` échouera (garde-fou). Pour désactiver proprement sans supprimer la config :

```bash
kubectl -n mineshark delete secret discord-chat-mod-config
kubectl -n mineshark rollout restart deployment/mc-mod
```

Le mod se chargera sans token (WARN non bloquant), le serveur tourne normalement.

### Un token a fuité (log, capture, commit accidentel)

1. **Immédiatement** : <https://discord.com/developers/applications> → ton app → Bot → **Reset Token**.
2. Colle le nouveau token dans `.env`.
3. `make discord-setup`.
4. Si tu as committé le token dans Git : purge l'historique avec `git filter-repo` (le simple `git rm` ne suffit pas, le token reste visible dans l'historique public).

---

## Cibles Make

| Commande                 | Rôle                                                                 |
|--------------------------|----------------------------------------------------------------------|
| `make secrets`           | Crée *tous* les Secrets K8s (dont Discord). Appelé par `make up`.    |
| `make discord-setup`     | Re-crée le Secret Discord + rollout mc-mod. À lancer après modif des `DISCORD_*` dans `.env`. |
| `make discord-status`    | Parse les logs mc-mod pour afficher l'état de la connexion JDA.      |
| `make discord-test`      | Envoie un message via RCON qui doit apparaître dans Discord.         |
| `make doctor`            | Rappelle si le bridge est configuré ou non (non bloquant).           |

---

## Pourquoi cette archi et pas une ConfigMap ?

- Une **ConfigMap** ne chiffre pas les données au repos et s'affiche en clair avec `kubectl describe`. Un Secret est affiché base64 et masqué par défaut (`kubectl get secret -o yaml` le montre mais `describe` non).
- Le mod lit un **fichier TOML sur le disque**, pas des variables d'environnement. Il faut donc *patcher* ce fichier au boot.
- L'approche "monter un TOML pré-rempli via ConfigMap/Secret" marcherait mais écraserait les autres champs du TOML (serverLogsChannelId, custom commands, etc.) — l'initContainer + sed est plus chirurgical.
