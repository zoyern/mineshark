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
cp .env.example .env
# Édite .env (au minimum : RCON_PASSWORD et CF_API_KEY si tu veux le moddé)

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
   Joueur Bedrock ──► │   :25565 / :19132   │  ───► mc-mod   (NeoForge, optionnel)
                      │                     │
                      └─────────────────────┘
```

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
make ssh            # SSH au VPS (cf. .env)
make backup         # backup manuel des données
make doctor         # vérifie env + cohérence config
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

- Aucun secret n'est commité (`.env`, RCON password, CurseForge key, Velocity forwarding secret).
- L'IP du VPS est dans `.env` (gitignored) — repo publiable sans fuite.
- Les serveurs backend (`mc-main`, `mc-mod`) ne sont accessibles qu'au proxy via le réseau interne K8s (`ClusterIP`).
- Le proxy authentifie les joueurs (`online-mode = true` côté Velocity), les backends font confiance via le forwarding secret.

---

## Statut & feuille de route

- [x] Phase 0 — Cross-play Java + Bedrock fonctionnel
- [x] Phase 1 — Repo propre, config centralisée, K3s + Docker alignés
- [ ] Phase 2 — Lobby Skywars (récupérer les maps de l'ancien serveur)
- [ ] Phase 3 — Domaine + TCPShield + Let's Encrypt
- [ ] Phase 4 — Site web + CMS custom relié au serveur

---

## Contribuer

Le projet est conçu pour qu'un non-dev puisse l'administrer via `make`. Si tu touches au code :

1. Garde la cohérence `docker-compose.yml` ↔ `k8s/` (les deux doivent refléter le même setup)
2. Toute valeur configurable va dans `.env.example`, pas en dur dans les fichiers
3. `make doctor` doit passer avant tout commit
