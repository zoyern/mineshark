# MineShark

Réseau Minecraft **Java + Bedrock cross-play** : proxy Velocity → serveur principal Paper (lobby + survie) + serveur moddé NeoForge optionnel à côté.

Pensé pour tourner partout pareil :
- **Local (dev)** via Docker Compose
- **Production VPS** via K3s (Kubernetes léger)

Tout passe par `make`. Aucune commande Docker ou kubectl à taper à la main.

---

## Démarrage rapide

```bash
git clone <url-repo> mineshark
cd mineshark

# 1. Init : crée data/, backups/, .env, et génère les secrets auto
#    (RCON + Velocity forwarding, tous dans data/secrets/)
make init

# 2. Édite .env — seule clé à remplir à la main : CF_API_KEY (modpack)
#    Tout le reste a des valeurs par défaut qui marchent.

# 3. Vérifie que tout est en place
make doctor

# En local (Docker Compose) :
make docker-up

# En production (VPS avec K3s installé) :
make up
```

C'est tout. Voir `make help` pour la liste des commandes.

---

## Architecture (vue d'avion)

```
                      ┌─────────────────────┐
   Joueur Java ───►   │                     │  ───► mc-main  (Paper, lobby+survie)
                      │   Velocity Proxy    │
   Joueur Bedrock ──► │   :25565 / :19132   │
                      │                     │
                      └─────────────────────┘

   Joueur moddé ─────────────────────────────► mc-mod  (NeoForge, :25566, standalone)
```

Le serveur moddé est volontairement **hors Velocity** : le proxy force un protocole vanilla incompatible NeoForge. Il s'accède donc directement via l'IP du VPS sur le port `25566`.

Le proxy Velocity est le **seul** point d'entrée public. Les serveurs MC backend ne sont jamais joints directement par les joueurs (sécurité + fluidité).

Détails complets : voir [`docs/architecture.md`](docs/architecture.md).

---

## Documentation

| Fichier | Pour qui |
|---|---|
| [`docs/quickstart.md`](docs/quickstart.md) | Mise en route en 5 minutes |
| [`docs/architecture.md`](docs/architecture.md) | Comprendre la stack en profondeur |
| [`docs/vps-setup.md`](docs/vps-setup.md) | Préparer un VPS Netcup avec K3s |
| [`docs/plugins.md`](docs/plugins.md) | Liste des plugins + comment en ajouter |
| [`docs/maps-migration.md`](docs/maps-migration.md) | Récupérer les maps 1.8 de l'ancien serveur vers 1.21 |

---

## Commandes principales

```bash
make help           # liste toutes les cibles disponibles

# Cycle de vie K8s (production)
make up             # déploie tout (proxy + main + mod en pause)
make down           # arrête tout (sans toucher aux données)
make re             # reset complet (down + up)
make status         # état pods, services, volumes
make logs-proxy     # logs Velocity
make logs-main      # logs serveur principal
make logs-mod       # logs serveur moddé

# Modes serveur moddé
make mod-on         # démarre le moddé (replicas=1)
make mod-off        # arrête le moddé (replicas=0)
make mod-reset      # supprime le PVC (à utiliser pour changer de modpack)

# Cycle de vie Docker (local)
make docker-up
make docker-down
make docker-re

# Administration
make init           # init complète : dossiers + .env + secrets
make ssh            # SSH au VPS (cf. .env)
make backup         # backup manuel des données
make doctor         # vérifie env + cohérence config
make show-secrets   # affiche les secrets auto-générés (RCON, forwarding)
```

---

## Stack technique

- **Proxy** : [Velocity](https://papermc.io/software/velocity) (PaperMC) avec [Geyser](https://geysermc.org/) + [Floodgate](https://geysermc.org/wiki/floodgate/) pour le cross-play Bedrock
- **Serveur principal** : [Paper](https://papermc.io/) 1.21.x (Java 21, Aikar flags)
- **Serveur moddé** : NeoForge via [AUTO_CURSEFORGE](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/auto-curseforge/) (modpack configurable dans `.env`)
- **Multi-version Java** : [ViaVersion](https://viaversion.com/) + ViaBackwards
- **Conteneurisation** : images [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/) — référence absolue de l'écosystème
- **Orchestration prod** : [K3s](https://k3s.io/) (Kubernetes léger, parfait pour mono-VPS)
- **Orchestration dev** : Docker Compose

---

## Sécurité

- Aucun secret n'est commité. Les deux secrets auto-générés (`rcon.secret`, `forwarding.secret`) vivent dans `data/secrets/` et `data/velocity/` — les deux gitignored.
- La seule clé à remplir à la main est `CF_API_KEY` (CurseForge) dans `.env`, gitignored lui aussi.
- L'IP du VPS est dans `.env` — repo publiable sans fuite.
- Le serveur principal `mc-main` est joignable uniquement par Velocity (Service K8s `ClusterIP`).
- Le serveur moddé `mc-mod` est publiquement joignable sur son propre port (`PORT_MOD=25566`) : Velocity ne peut pas proxy NeoForge. Ça reste sans risque car la sécurité repose sur `online-mode = true` + RCON isolé en ClusterIP.
- Le forwarding secret Velocity est **partagé** entre le proxy et les backends via un seul fichier (`data/velocity/forwarding.secret`) monté en K8s Secret et en volume Docker.

---

## Statut & feuille de route

- [x] Phase 0 — Cross-play Java + Bedrock fonctionnel
- [x] Phase 1 — Repo propre, config centralisée, K3s + Docker alignés, CI lint
- [ ] Phase 2 — Lobby + Skywars (récupérer les maps de l'ancien serveur — cf. `docs/maps-migration.md`)
- [ ] Phase 3 — Domaine + TCPShield + anti-cheat Grim
- [ ] Phase 4 — Site Next.js + API NestJS + Postgres (cf. `web/`, `api/`, `k8s/postgres/`)

---

## Contribuer

Le projet est conçu pour qu'un non-dev puisse l'administrer via `make`. Si tu touches au code :

1. Garde la cohérence `docker-compose.yml` ↔ `k8s/` (les deux doivent refléter le même setup)
2. Toute valeur configurable va dans `.env.example`, pas en dur dans les fichiers
3. `make doctor` doit passer avant tout commit
