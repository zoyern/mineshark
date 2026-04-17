# Plugins MineShark

Choix raisonné des plugins pour le serveur principal Paper. Tous compatibles **1.21.x** (vérifié avril 2026).

---

## Stack par défaut (fournie via `.env` `PLUGINS_MODRINTH`)

| Plugin | Rôle | Pourquoi celui-ci |
|---|---|---|
| **Floodgate** | Permet aux joueurs Bedrock de jouer sans compte Java | Indispensable pour le cross-play. Pas sur Modrinth → URL directe GeyserMC |
| **LuckPerms** | Système de permissions et de rangs | Standard absolu de l'écosystème depuis 2018. Aucune alternative sérieuse |
| **WorldEdit** | Édition rapide de zones (pose/copie de blocs en masse) | Utilisé pour construire les maps lobby et skywars |
| **WorldGuard** | Définition de zones protégées (no-PvP, no-build...) | Couple naturel avec WorldEdit, indispensable pour un lobby |
| **CoreProtect** | Logs de tous les événements (placement, destruction, chat) avec rollback | Anti-grief / forensique, sauve la vie après un raid |
| **Multiverse-Core** | Gestion de plusieurs mondes dans un même serveur | Un monde "lobby" + un monde "skywars" + un monde "survie" sur le même serveur Paper |
| **PlaceholderAPI** | Pont entre plugins (variables interchangeables) | Beaucoup de plugins UI/scoreboard en dépendent |
| **Spark** | Profiler de performances Java + analyse mémoire | Trouver d'où vient le lag en 2 commandes |
| **Chunky** | Pré-génération du monde en arrière-plan | Réduit massivement le lag des joueurs explorateurs |
| **DecentHolograms** | Hologrammes en jeu (sans entité) | Remplace HolographicDisplays (legacy). Lobby joli |

---

## Pour ajouter un plugin

### Méthode 1 (recommandée) — Via Modrinth

Si le plugin existe sur [Modrinth](https://modrinth.com/plugins) :

```bash
# 1. Trouve le slug Modrinth (la fin de l'URL)
#    Ex: https://modrinth.com/plugin/luckperms → slug = "luckperms"

# 2. Ajoute-le à .env
#    PLUGINS_MODRINTH=floodgate,luckperms,...,nouveau-plugin

# 3. Synchronise k8s/main/deployment.yaml MODRINTH_PROJECTS (ligne synced)

# 4. Recharge
make docker-re   # ou make re sur le VPS
```

### Méthode 2 — Via URL directe (jars custom)

Pour les plugins absents de Modrinth (souvent ceux de SpigotMC) :

1. Récupère l'URL de téléchargement direct du `.jar`
2. Ajoute-la dans le bloc `PLUGINS:` de `docker-compose.yml` ET `k8s/main/deployment.yaml`
3. `make re`

---

## Plugins prévus pour la Phase 2 (lobby + Skywars)

À ajouter quand on récupère les maps de l'ancien serveur :

| Plugin | Rôle | Choix |
|---|---|---|
| **Multiverse-Inventories** | Inventaires séparés par monde | Indispensable avec Multiverse pour un vrai lobby |
| **CommandAPI** | Helper pour plugins custom | Si on écrit nos propres plugins |
| **Skywars Reloaded X** | Skywars moderne, maintenu | Fork actif du Skywars original |
| **BedWars1058** | BedWars complet | Si on veut diversifier vers BedWars |
| **TabList** | Customise la touche TAB | UX |
| **Vault** | Pont économie/permissions | Pré-requis de beaucoup de plugins |

---

## Plugins anti-cheat (Phase 3, quand on aura des joueurs)

| Plugin | État 2026 | Note |
|---|---|---|
| **Grim Anticheat** | ✓ référence open-source | À installer dès qu'on ouvre au public |
| Matrix | ✗ mort | Ne plus utiliser |
| AAC | ✗ mort | Ne plus utiliser |
| Vulcan | ⚠️ payant mais sérieux | Alternative à Grim si besoin de support pro |

---

## À NE PAS installer

- **EssentialsX** : legacy, lourd, beaucoup de plugins modernes le remplacent en mieux
- **HolographicDisplays** : abandonné — DecentHolograms à la place
- **PermissionsEx / GroupManager** : abandonnés — LuckPerms à la place
- **Anti-cheats premium pas open-source** : Grim suffit dans 99% des cas
- **Tout plugin qui n'a pas eu de release depuis 2024** : risque de plantage sur 1.21.x

---

## Vérifier la compatibilité d'un plugin

Avant d'ajouter un plugin :

1. Va sur sa page Modrinth/SpigotMC/GitHub
2. Vérifie qu'il liste **1.21.x** dans les versions supportées
3. Lis la dernière release note
4. Si pas de mise à jour depuis 6+ mois → suspect, cherche une alternative
