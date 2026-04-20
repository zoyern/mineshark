# Plugins — catalogue unifié

**Source de vérité unique** pour tous les plugins du serveur principal MineShark. Les fichiers opérationnels (`.env`, `.env.example`, `k8s/main/deployment.yaml`, `plugins/manual/`) renvoient ici et DOIVENT rester synchrones avec ce document.

> **Règle d'or** — ne jamais ajouter un plugin ailleurs sans l'ajouter ici d'abord. Si tu touches `.env` ou le deployment, mets à jour la même ligne dans ce fichier dans le même commit.

---

## 1. Ordre de préférence des sources

On a **4 mécanismes** de distribution des plugins. Chacun a sa place, avec un ordre de préférence strict :

| Rang | Source | Mécanisme itzg | Quand | Avantage |
|---|---|---|---|---|
| 1 | **Modrinth** | `MODRINTH_PROJECTS` | plugin open-source, release récente sur Modrinth | CDN rapide, versionning propre, permet pin `slug:version` |
| 2 | **Spiget (SpigotMC)** | `SPIGET_RESOURCES` | plugin free pas sur Modrinth (ou lag Modrinth) | énorme catalogue legacy, ID stable |
| 3 | **URL directe** | `PLUGINS` (multi-lignes) | releases GitHub, builds CI publics, jars qui lag sur les deux précédents | contrôle exact de la version, pas de middleware |
| 4 | **Jar manuel** | `plugins/manual/*.jar` + hostPath + initContainer | BuiltByBit payant, plugin disparu, jar custom, pin d'une version absente ailleurs | dernière cartouche, nécessite `make plugins-sync` |

**Règle d'arbitrage** : on utilise le rang le plus bas possible. Si un plugin passe de rang 4 à rang 1 (ex. sort sur Modrinth), on le migre et on retire du rang précédent.

---

## 2. Stack actuelle (avril 2026)

### 2.1 Core (fond de roulement)

| Plugin | Rôle | Source | Identifiant | Version | Commentaire |
|---|---|---|---|---|---|
| **LuckPerms** | permissions + rangs | Modrinth | `luckperms` | latest | standard absolu, aucune alternative sérieuse |
| **WorldEdit** | édition rapide de zones | Modrinth | `worldedit:7.3.16` | **PIN 7.3.16** | sans pin, 7.4.x tente un adapter 1.21.6 avec warning ; 7.3.16 est officiellement testé 1.21.8 |
| **WorldGuard** | régions protégées | Modrinth | `worldguard` | latest | couple naturel WE |
| **CoreProtect** | logs + rollback | Modrinth | `coreprotect` | latest | fork CE 23.x, supporte 1.21.8 |
| **Multiverse-Core** | multi-mondes | Modrinth | `multiverse-core` | latest | un monde par mini-jeu |
| **DecentHolograms** | hologrammes sans entité | Modrinth | `decentholograms` | latest | remplace HolographicDisplays (legacy) |
| **PlaceholderAPI** | pont variables inter-plugins | Modrinth | `placeholderapi` | latest | dep de plein de plugins UI |
| **Chunky** | pré-gen du monde | Modrinth | `chunky` | latest | réduit le lag exploration |
| **Vault** | pont économie/perm | Spiget | `34315` | latest | prérequis beaucoup de plugins |
| **ProtocolLib** | lib paquets | Spiget | `1997` | latest | dep WorldGuard/SWR/AuthMe/etc |
| **Floodgate** | joueurs Bedrock | URL (GeyserMC) | `v2/floodgate/latest/spigot` | latest | cross-play, pas sur Modrinth |
| **ViaVersion** | compat clients récents | URL (GitHub) | `5.8.1` | 5.8.1 | pin release GitHub (itzg ne reconnaît pas le slug Modrinth à temps) |
| **ViaBackwards** | compat clients anciens | URL (GitHub) | `5.8.1` | 5.8.1 | permet aux 1.8.x de se connecter (mini-games PvP classiques) |
| **EssentialsX** | commandes staples (/home, /tpa, /spawn, /msg...) | URL (GitHub) | `2.21.2` | 2.21.2 | tiré direct de GitHub car Modrinth lag (ex. 2.21.0 vs 2.21.2) |

### 2.2 Navigation lobby ↔ mini-jeux

| Plugin | Rôle | Source | Identifiant | Commentaire |
|---|---|---|---|---|
| **Advanced Portals** | portails rectangulaires ou pads custom avec `command` ou `teleport` | Modrinth | `advanced-portals` | plus propre que `essentials:warp`, permet créer un vrai hub graphique. Compat 1.21.x. Migré de Spiget (ID `14356`) vers Modrinth le 2026-04-20 : l'API Spiget renvoyait HTTP 500 sur le download → crashloop init. |

Utilisation type :
```
/portal create portalName --destination skywars_hub --triggerblock PORTAL
```

### 2.3 Mini-jeux multijoueurs (2-16 joueurs)

| Plugin | Jeu | Source | Identifiant | Version/Note |
|---|---|---|---|---|
| **TntRun Reloaded** | TntRun | Spiget | `53359` | compat 1.13 → 1.21 |
| **SkyWarsReloaded** | SkyWars (fork **lukasvdgaag**, FREE) | Spiget | `69436` | v3 FREE — ⚠️ ne pas confondre avec l'original Dabo Ross parti en premium ; on utilise bien le fork libre. Fournit un générateur de chunks VOID intégré (`-g SkyWarsReloaded`). |
| **ScreamingBedWars** | BedWars | Spiget | `63714` | fork actif et maintenu (ex-BedWars1058 abandonné fin 2023 à 1.20.3). Support 1.21.x natif. |
| **Spleef_reloaded** | Spleef / Splegg | Spiget | `118673` | GPL, maintenu par steve4744 (remplace SpleefX dont la version gratuite est morte). |
| **MurderMystery** (Plugily-Projects) | Meurtre / Mystère | Spiget | `66614` | rôles Murderer / Detective / Innocent, compat 1.21.x. |
| **OITC** (Despical) | One In The Chamber | Spiget | `81185` | ressurection propre d'OITC classique par l'équipe Plugily. |

### 2.4 Skyblock moderne (OneBlock)

OneBlock = 1 bloc central qui donne matériaux et débloque des phases progressives. Réalisé via **BentoBox** (plateforme gamemode) + l'addon **AOneBlock**.

| Plugin | Rôle | Source | Identifiant | Installation |
|---|---|---|---|---|
| **BentoBox** | plateforme (core) | Spiget | `73261` | itzg télécharge auto dans `/data/plugins/` |
| **AOneBlock** (addon) | le gamemode OneBlock lui-même | Jar manuel | GitHub releases BentoBoxWorld/AOneBlock | Posé dans `plugins/manual/bentobox-addons/AOneBlock-X.Y.Z.jar`. L'initContainer `copy-manual-plugins` le copie dans `/data/plugins/BentoBox/addons/` (PAS dans `/data/plugins/` directement — BentoBox ignore les addons placés au mauvais endroit). |
| **Level** (addon, optionnel) | score/ranking par île | Jar manuel | BentoBoxWorld/Level | même workflow |

> 💡 Les addons BentoBox ne sont **pas** des plugins au sens Bukkit. Ils doivent être dans `plugins/BentoBox/addons/` — d'où le sous-répertoire spécial `bentobox-addons/` côté repo et le chemin spécifique côté initContainer.

### 2.5 Refusés / pas retenus

| Plugin | Pourquoi on l'a écarté |
|---|---|
| **TheTower** (Wynncraft-like) | pas de plugin grand public maintenu en 2026. Serait un projet à part entière. |
| **SpleefX (free)** | la version gratuite est abandonnée depuis 2023 ; seul le fork premium est vivant. Remplacé par Spleef_reloaded. |
| **BedWars1058** | dernière release fin 2023 bloquée à 1.20.3. Remplacé par ScreamingBedWars. |
| **SkyWars original (Dabo Ross)** | parti en premium. On utilise le fork libre **lukasvdgaag** (SkyWarsReloaded `69436`). |
| **HolographicDisplays** | abandonné. Remplacé par DecentHolograms. |
| **PermissionsEx / GroupManager** | abandonnés. LuckPerms à la place. |
| **Matrix / AAC (anti-cheats)** | morts. Grim Anticheat (open-source) quand on ouvrira au public. |

---

## 3. Workflow — ajouter un plugin

### 3.1 Via Modrinth (rang 1, préféré)

1. Trouver le slug Modrinth (fin de l'URL, ex. `https://modrinth.com/plugin/chunky` → `chunky`).
2. Vérifier que la dernière version supporte 1.21.8 (bouton *Versions* sur la page).
3. Ajouter le slug (éventuellement `slug:version` pour pin) :
   - dans **ce document** (section 2),
   - dans `.env` → `PLUGINS_MODRINTH`,
   - dans `.env.example` (mêmes valeurs),
   - dans `k8s/main/deployment.yaml` → `MODRINTH_PROJECTS`.
4. `make redeploy-plugins` (force pull des nouvelles dépendances + rollout).

### 3.2 Via Spiget (rang 2)

1. Récupérer l'ID numérique Spigot (fin de l'URL : `https://www.spigotmc.org/resources/xxxx.<ID>/`).
2. Vérifier dans l'onglet *Updates* que la dernière version supporte 1.21.8.
3. Ajouter l'ID aux mêmes 4 endroits que ci-dessus, mais sous `PLUGINS_SPIGET` / `SPIGET_RESOURCES`.
4. `make redeploy-plugins`.

### 3.3 Via URL directe (rang 3)

1. Récupérer l'URL du `.jar` (release GitHub ou download CI).
2. Ajouter la ligne dans le bloc `PLUGINS:` (multi-lignes) de `k8s/main/deployment.yaml` et `docker-compose.yml`.
3. Documenter ici.
4. `make redeploy-plugins`.

### 3.4 Via jar manuel (rang 4)

Voir `plugins/manual/README.md` pour le workflow complet. TL;DR :

```
# 1. Dépose le jar
cp ~/Downloads/MonPlugin-1.2.3.jar plugins/manual/

# 2. (addon BentoBox seulement) sous-dossier dédié
cp ~/Downloads/AOneBlock-1.23.0.jar plugins/manual/bentobox-addons/

# 3. Sync sur le VPS + rollout
make plugins-sync
```

---

## 4. Workflow — retirer un plugin

1. Retirer la ligne dans ce document (section 2) et dans `.env` + `.env.example` + `k8s/main/deployment.yaml`.
2. Pour les jars manuels : supprimer dans `plugins/manual/` puis `make plugins-sync` (utilise `rsync --delete`).
3. **Attention** — le plugin reste dans le PVC `/data/plugins/` du pod (itzg ne purge pas ce qu'il n'a pas téléchargé). Le nettoyer explicitement :
   ```
   kubectl -n mineshark exec deploy/mc-main -c minecraft -- rm /data/plugins/MonPlugin-*.jar
   make restart-main
   ```

---

## 5. Vérifier la compatibilité avant ajout

Avant d'ajouter un plugin :

1. Dernière release < 6 mois idéalement, < 18 mois acceptable.
2. Compatibilité **1.21.x** explicite.
3. Si Spiget : le jar compilé doit être pour Paper (certains ne visent que Spigot/Bukkit).
4. Pas d'incompatibilité listée avec ProtocolLib ≥ 5.3 ou ViaVersion ≥ 5.8.

Commandes utiles :

```bash
# Modrinth — dernière version compatible 1.21.8
curl -s "https://api.modrinth.com/v2/project/<slug>/version" \
  | jq '.[] | select(.game_versions[] == "1.21.8") | {version_number, date_published}' \
  | head -40

# Spiget — dernière version + date
curl -s "https://api.spiget.org/v2/resources/<id>" | jq '{name, version: .version.id, updateDate, tag}'

# Plugin déjà dans le pod
make rcon CMD="version MonPlugin"
```

---

## 6. Historique des décisions (log)

| Date | Décision | Pourquoi |
|---|---|---|
| 2026-01 | WorldEdit pinned 7.3.16 | 7.4.x tente fallback adapter 1.21.6, warnings "not tested" |
| 2026-01 | EssentialsX via URL GitHub | Modrinth lag (2.21.0 vs 2.21.2) |
| 2026-01 | SkyWarsReloaded (fork lukasvdgaag, `69436`) | original parti premium, fork libre maintenu |
| 2026-04 | Ajout Advanced Portals (`14356`) | besoin d'un hub visuel lobby→skywars sans éditer EssentialsX warps |
| 2026-04 | Ajout Spleef_reloaded (`118673`) | SpleefX free abandonné |
| 2026-04 | BedWars1058 → ScreamingBedWars (`63714`) | BW1058 coincé à 1.20.3, SBW supporte 1.21.x |
| 2026-04 | Ajout MurderMystery (`66614`) + OITC (`81185`) (Plugily-Projects) | mini-jeux 2-4 joueurs demandés |
| 2026-04 | Ajout BentoBox (`73261`) + AOneBlock (jar manuel, bentobox-addons/) | OneBlock moderne type Hypixel |
| 2026-04 | TheTower : **abandonné** | pas de plugin maintenu, nécessiterait un serveur dédié et un dev custom |

---

## 7. Où tout est synchronisé (checklist de cohérence)

Pour un plugin X (slug ou ID), il doit apparaître **à l'identique** dans :

- [ ] `docs/plugins.md` — section 2 (ce document)
- [ ] `.env` — ligne `PLUGINS_MODRINTH=` ou `PLUGINS_SPIGET=`
- [ ] `.env.example` — même ligne, même valeur
- [ ] `k8s/main/deployment.yaml` — `MODRINTH_PROJECTS` / `SPIGET_RESOURCES` / `PLUGINS`
- [ ] (si jar manuel) `plugins/manual/*.jar` committé dans le repo

Hook rappel : l'intro du deployment.yaml porte la mention `# synced with .env VAR` à respecter.
