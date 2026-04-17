# MineShark — Guide V3 (Avril 2026)

> Guide complet, vérifié et corrigé pour monter un réseau Minecraft hybride (Java + Bedrock) avec K3s.
> Testé en local (WSL2) d'abord, puis déployé sur VPS.
> Dernière mise à jour : 15 avril 2026

---

## Table des matières

1. [Architecture](#1-architecture)
2. [Dimensionnement RAM](#2-dimensionnement-ram)
3. [Choix du VPS](#3-choix-du-vps)
4. [Stack Technique — Résumé](#4-stack-technique--résumé)
5. [Setup Local (WSL2) — Test ce soir](#5-setup-local-wsl2--test-ce-soir)
6. [Docker Compose — Validation locale](#6-docker-compose--validation-locale)
7. [K3s — Installation](#7-k3s--installation)
8. [K3s — Concepts (comparaison Docker Compose)](#8-k3s--concepts-comparaison-docker-compose)
9. [Manifestes K8s — Namespace & Secrets](#9-manifestes-k8s--namespace--secrets)
10. [Velocity — Proxy + GeyserMC + Floodgate](#10-velocity--proxy--geysermc--floodgate)
11. [Lobby — Paper (Hub)](#11-lobby--paper-hub)
12. [Jeux — Paper (Plugins/Minijeux)](#12-jeux--paper-pluginsminijeux)
13. [Survie — NeoForge (Modded Together)](#13-survie--neoforge-modded-together)
14. [Dev — Paper (Sandbox)](#14-dev--paper-sandbox)
15. [Routage Réseau — Traefik TCP/UDP](#15-routage-réseau--traefik-tcpudp)
16. [TCPShield — Protection DDoS & DNS](#16-tcpshield--protection-ddos--dns)
17. [Site Web — Architecture prévue (Phase 3)](#17-site-web--architecture-prévue-phase-3)
18. [Structure du Repo GitHub](#18-structure-du-repo-github)
19. [Makefile](#19-makefile)
20. [CI/CD — GitHub Actions](#20-cicd--github-actions)
21. [Optimisations — JVM, Pregen, Monitoring](#21-optimisations--jvm-pregen-monitoring)
22. [Setup VPS Production (Debian 12)](#22-setup-vps-production-debian-12)
23. [FAQ](#23-faq)
24. [Roadmap](#24-roadmap)
25. [Sources & Références](#25-sources--références)

---

## 1. Architecture

```
Internet (Joueurs)
       │
       ▼
┌─────────────────┐
│   TCPShield     │  ← Protection DDoS, masque l'IP du VPS
│   (gratuit)     │  ← Les joueurs se connectent à play.mineshark.fr
└────────┬────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│              VPS (Contabo Cloud VPS 30)               │
│          Debian 12 + K3s (single node)                │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Traefik Ingress (inclus K3s)                   │  │
│  │  Port 443 → Site web (Phase 3)                  │  │
│  │  Port 25565/TCP → Velocity (Java)               │  │
│  │  Port 19132/UDP → Velocity (Bedrock)            │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │                              │
│  ┌──────────────────────▼──────────────────────────┐  │
│  │         Velocity Proxy (itzg/mc-proxy)          │  │
│  │   + GeyserMC (crossplay Bedrock → Java)         │  │
│  │   + Floodgate (auth Bedrock sans compte Java)   │  │
│  │   + TCPShield Plugin (restore real IP)           │  │
│  │   Écoute: 25577/TCP interne, 19132/UDP          │  │
│  └─────┬──────────┬──────────┬───────────┬─────────┘  │
│        │          │          │           │             │
│   ┌────▼────┐┌────▼────┐┌───▼─────┐┌────▼────┐       │
│   │ lobby   ││ jeux    ││ survie  ││  dev    │       │
│   │ Paper   ││ Paper   ││NeoForge ││ Paper   │       │
│   │ :25565  ││ :25565  ││ :25565  ││ :25565  │       │
│   │         ││plugins  ││ Modded  ││sandbox  │       │
│   │ hub     ││minijeux ││Together ││ test    │       │
│   │ portails││ pvp     ││         ││         │       │
│   └─────────┘└─────────┘└─────────┘└─────────┘       │
│   ClusterIP   ClusterIP  ClusterIP  ClusterIP         │
│   (interne)   (interne)  (interne)  (interne)         │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Volumes Persistants (PVC K3s)                  │  │
│  │  server-proxy/  server-lobby/  server-plugins/  │  │
│  │  server-modded/ server-sandbox/                 │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │  Site Web — Phase 3                             │  │
│  │  Next.js :3000 │ NestJS :4000 │ PostgreSQL :5432│  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

### Les 4 serveurs Minecraft

| Serveur | Logiciel | Rôle | Crossplay Bedrock |
|---------|----------|------|-------------------|
| **lobby** | Paper | Hub d'arrivée, portails, NPC de navigation | Oui (GeyserMC) |
| **jeux** | Paper | Minijeux, PvP, survie vanilla, maps custom | Oui (GeyserMC) |
| **survie** | NeoForge | Modded Together (RPG, magie, tech, quêtes) | Non (mods incompatibles) |
| **dev** | Paper | Sandbox de test, peut crash sans affecter le reste | Oui (GeyserMC) |

### Pourquoi cette architecture ?

- **Isolation** : chaque serveur dans son Pod K3s. Si le dev crash, la survie continue.
- **Scalabilité** : ajouter un serveur = ajouter un fichier YAML.
- **Apprentissage** : K3s sur un vrai projet, pas un tuto hello-world.
- **Point d'entrée unique** : une seule IP, Velocity route les joueurs.
- **Sécurité** : les backends sont en ClusterIP (inaccessibles depuis l'extérieur). Seul Velocity est exposé.

---

## 2. Dimensionnement RAM

### Formule JVM

```
RAM conteneur = Heap (-Xmx) + Off-Heap (~15-20% du Heap) + marge OS
```

L'Off-Heap inclut : Metaspace (définitions de classes), cache JIT (compilateur just-in-time), Thread Stacks (piles d'exécution des fils), Direct NIO Buffers (tampons réseau Netty).

### Allocation par composant

| Composant | Heap (-Xmx) | Limit conteneur | Justification |
|-----------|-------------|-----------------|---------------|
| OS + K3s + Traefik + Flannel | — | ~1.2 Go | Noyau Linux, kubelet, CNI, SQLite |
| Velocity + GeyserMC + Floodgate | 512 Mo | 768 Mo | Proxy léger, traduction protocolaire Java/Bedrock |
| Lobby (Paper) | 1 Go | 1.5 Go | Hub simple, peu d'entités, difficulty=peaceful |
| Jeux (Paper) | 2 Go | 2.5 Go | Plugins, minijeux, PvP, 20+ joueurs |
| Survie (NeoForge) | 6 Go | 7 Go | Modpack lourd (150+ mods), génération de chunks |
| Dev (Paper) | 1.5 Go | 2 Go | Sandbox test, éteint quand pas utilisé |
| **TOTAL (tout actif)** | **11 Go** | **~15 Go** | |
| **TOTAL (dev éteint)** | **9.5 Go** | **~13 Go** | |

### Sur un VPS 24 Go (Contabo Cloud VPS 30)

- Tout actif : **15 Go utilisés → 9 Go libres** pour le Page Cache (cache fichiers du noyau), le site web futur, et la marge de sécurité
- Dev éteint : **13 Go utilisés → 11 Go libres**

### Sur un VPS 16 Go (Netcup VPS 2000)

- Tout actif : **15 Go utilisés → 1 Go libre** — très serré, risque d'OOM (Out-Of-Memory) si pic de joueurs
- Dev éteint : **13 Go utilisés → 3 Go libres** — viable mais pas de marge pour le site web

**Conclusion** : Contabo 24 Go à 14€ est le choix rationnel. 16 Go marche mais c'est la corde raide.

---

## 3. Choix du VPS

### Comparatif vérifié (avril 2026)

| Fournisseur | Plan | vCPU | RAM | Stockage | Prix/mois TTC | Note |
|-------------|------|------|-----|----------|---------------|------|
| **Contabo** | Cloud VPS 30 | 8 partagés | **24 Go** | 200 Go NVMe | **~14€** (~11€ en annuel) | **Recommandé** — meilleur RAM/€ |
| Netcup | VPS 2000 G12 | 8 partagés | 16 Go | 512 Go SSD | ~17€ | Réseau stable 2.5 Gbps, RAM insuffisante |
| Netcup | RS 2000 G12 | 8 **dédiés** EPYC | 16 Go | 512 Go NVMe | ~20€ | CPU dédié top pour MC, mais 16 Go seulement |
| Hetzner | CX42 | 8 partagés | 16 Go | 160 Go | ~21-22€ | Trop cher depuis augmentation 2026 |

### Recommandation finale

**Contabo Cloud VPS 30 à ~14€/mois** (ou ~11€ en engagement annuel, sans frais de setup).

- 24 Go de RAM = confortable pour les 4 serveurs MC + site web futur
- Datacenter disponible en Europe (Allemagne — Munich)
- Port réseau 600 Mbit/s = ~75 Mo/s de bande passante dédiée (largement suffisant pour 30 joueurs MC, chaque joueur consomme ~50-100 Kbit/s)
- 8 vCores partagés = correct pour MC si on fait la prégénération Chunky

**Point faible Contabo** : CPU partagé, performances monocœur inférieures à Netcup EPYC dédié. Compensé par la prégénération (section 21).

---

## 4. Stack Technique — Résumé

| Composant | Technologie | Version | Rôle |
|-----------|-------------|---------|------|
| OS | Debian 12 (Bookworm) | Stable | Frugal, stable, standard serveur |
| Orchestrateur | K3s | Latest | Kubernetes léger (~60 Mo), inclut Traefik + Flannel + CoreDNS |
| Proxy MC | Velocity | Latest | Routage joueurs entre serveurs, auth Mojang/Xbox |
| Crossplay | GeyserMC + Floodgate | Latest | Traduit Bedrock (UDP) → Java (TCP), auth sans compte Java |
| Hub | PaperMC | 1.21.4 | Serveur optimisé (fork Spigot, 40-60% plus rapide) |
| Modded | NeoForge | Auto (via modpack) | Fork moderne de Forge, modpack "Modded Together" |
| Anti-DDoS | TCPShield | Gratuit | Reverse proxy Anycast, masque l'IP du VPS |
| Images Docker | itzg/minecraft-server | Latest | Standard industriel pour MC sous Docker |
| Image Proxy | itzg/mc-proxy | Latest | Image dédiée aux proxys (Velocity, BungeeCord, Waterfall) |
| CI/CD | GitHub Actions | — | Deploy auto sur push main, backup quotidien |
| Site web (Phase 3) | Next.js + NestJS + PostgreSQL | — | Dashboard joueurs, stats, panel admin |

### Clarification des images itzg

L'écosystème itzg a **deux images distinctes** :

| Image | Usage | Variable TYPE |
|-------|-------|--------------|
| `itzg/mc-proxy` | Proxys : Velocity, BungeeCord, Waterfall | `TYPE=VELOCITY` |
| `itzg/minecraft-server` | Serveurs : Paper, NeoForge, Forge, Fabric, Vanilla | `TYPE=PAPER`, `TYPE=AUTO_CURSEFORGE`, etc. |

**Erreur courante** : utiliser `itzg/minecraft-server` avec `TYPE=VELOCITY` — ça ne fonctionne pas. Le proxy Velocity nécessite `itzg/mc-proxy`.

---

## 5. Setup Local (WSL2) — Test ce soir

### 5.1 Prérequis

Tu as besoin de Docker Desktop (ou Docker Engine dans WSL2) pour le test Docker Compose local. K3s viendra après.

```bash
# Vérifie que Docker tourne dans WSL2
docker --version
docker compose version

# Si pas installé :
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Déconnecte/reconnecte WSL2
```

### 5.2 Cloner le repo

```bash
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/zoyern/mineshark.git
cd mineshark
```

### 5.3 Structure de fichiers à créer

```
mineshark/
├── docker-compose.yml          # Test local
├── docker-compose.override.yml # Overrides locaux (RAM réduite pour PC)
├── .env                        # Clé API CurseForge (jamais commité)
├── .env.example                # Template sans la vraie clé
├── k8s/                        # Manifestes K3s (production)
│   ├── base/
│   ├── velocity/
│   ├── lobby/
│   ├── jeux/
│   ├── survie/
│   ├── dev/
│   └── traefik/
├── configs/
│   └── velocity/
│       └── velocity.toml
├── scripts/
│   ├── setup-vps.sh
│   ├── backup.sh
│   └── restore.sh
├── .github/workflows/
├── Makefile
├── .gitignore
└── README.md
```

---

## 6. Docker Compose — Validation locale

### 6.1 Fichier .env

```bash
# .env (jamais commité — dans .gitignore)
CF_API_KEY=ta_cle_api_curseforge_ici
```

Pour obtenir la clé : https://console.curseforge.com/ → créer un compte → générer une API key.

### 6.2 Fichier .env.example

```bash
# .env.example (commité — template)
CF_API_KEY=your_curseforge_api_key_here
```

### 6.3 docker-compose.yml

```yaml
# =============================================================
#  MineShark — Docker Compose (validation locale)
#  Réseau : proxy → lobby + jeux + survie + dev
#  Les backends sont isolés dans le réseau interne Docker.
# =============================================================

services:
  # ─────────────────────────────────────────────────
  # PROXY — Velocity + GeyserMC + Floodgate
  # Point d'entrée unique. Seul service exposé.
  # ─────────────────────────────────────────────────
  proxy-velocity:
    image: itzg/mc-proxy:latest
    container_name: ms-proxy
    environment:
      TYPE: "VELOCITY"
      # Mémoire proxy — 512 Mo suffit pour 30 joueurs
      MEMORY: "512M"
      # Plugins auto-téléchargés au démarrage
      # GeyserMC : traduit Bedrock (UDP/RakNet) → Java (TCP)
      # Floodgate : auth Bedrock sans compte Java payé
      PLUGINS: |
        https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity
    ports:
      # Java : port standard 25565 → Velocity écoute sur 25577
      - "25565:25577"
      # Bedrock : port standard 19132 (UDP)
      - "19132:19132/udp"
    volumes:
      - ./data/velocity:/server
    networks:
      - mc-network
    restart: unless-stopped

  # ─────────────────────────────────────────────────
  # LOBBY — Paper (Hub d'arrivée)
  # Serveur par défaut à la connexion.
  # Portails vers les autres serveurs.
  # ─────────────────────────────────────────────────
  hub-paper:
    image: itzg/minecraft-server:latest
    container_name: ms-lobby
    environment:
      TYPE: "PAPER"
      VERSION: "1.21.4"
      EULA: "TRUE"
      MEMORY: "1G"
      USE_AIKAR_FLAGS: "true"
      # Auth déléguée au proxy Velocity
      ONLINE_MODE: "FALSE"
      MOTD: "§b§lMineShark §7- §eLobby"
      MAX_PLAYERS: "50"
      DIFFICULTY: "peaceful"
      VIEW_DISTANCE: "8"
      SIMULATION_DISTANCE: "6"
      # Floodgate côté backend pour les skins Bedrock
      PLUGINS: |
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
    volumes:
      - ./data/lobby:/data
    networks:
      - mc-network
    restart: unless-stopped

  # ─────────────────────────────────────────────────
  # JEUX — Paper (Plugins, Minijeux, PvP)
  # Serveur de gameplay principal.
  # ─────────────────────────────────────────────────
  jeux-paper:
    image: itzg/minecraft-server:latest
    container_name: ms-jeux
    environment:
      TYPE: "PAPER"
      VERSION: "1.21.4"
      EULA: "TRUE"
      MEMORY: "2G"
      USE_AIKAR_FLAGS: "true"
      ONLINE_MODE: "FALSE"
      MOTD: "§b§lMineShark §7- §aJeux & Plugins"
      MAX_PLAYERS: "50"
      DIFFICULTY: "normal"
      VIEW_DISTANCE: "10"
      SIMULATION_DISTANCE: "8"
      PLUGINS: |
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
    volumes:
      - ./data/jeux:/data
    networks:
      - mc-network
    restart: unless-stopped

  # ─────────────────────────────────────────────────
  # SURVIE — NeoForge (Modded Together)
  # Modpack RPG/magie/tech. Le plus gourmand en RAM.
  # ─────────────────────────────────────────────────
  survie-neoforge:
    image: itzg/minecraft-server:latest
    container_name: ms-survie
    environment:
      # AUTO_CURSEFORGE télécharge le modpack complet automatiquement
      # Il détecte le mod loader (NeoForge) et la version MC depuis le manifest
      TYPE: "AUTO_CURSEFORGE"
      CF_SLUG: "moddedtogether"
      CF_API_KEY: "${CF_API_KEY}"
      EULA: "TRUE"
      # 6 Go minimum pour un modpack 150+ mods
      MEMORY: "6G"
      USE_AIKAR_FLAGS: "true"
      ONLINE_MODE: "FALSE"
      MOTD: "§b§lMineShark §7- §cSurvie Modee"
      MAX_PLAYERS: "30"
      DIFFICULTY: "hard"
      VIEW_DISTANCE: "8"
      SIMULATION_DISTANCE: "6"
    volumes:
      - ./data/survie:/data
    networks:
      - mc-network
    restart: unless-stopped

  # ─────────────────────────────────────────────────
  # DEV — Paper (Sandbox de test)
  # Ton terrain de jeu. Peut crash sans affecter le reste.
  # ─────────────────────────────────────────────────
  dev-paper:
    image: itzg/minecraft-server:latest
    container_name: ms-dev
    environment:
      TYPE: "PAPER"
      VERSION: "1.21.4"
      EULA: "TRUE"
      MEMORY: "1500M"
      USE_AIKAR_FLAGS: "true"
      ONLINE_MODE: "FALSE"
      MOTD: "§b§lMineShark §7- §aDev §c[UNSTABLE]"
      MAX_PLAYERS: "10"
      DIFFICULTY: "peaceful"
      GAMEMODE: "creative"
      PLUGINS: |
        https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
    volumes:
      - ./data/dev:/data
    networks:
      - mc-network
    restart: unless-stopped

networks:
  mc-network:
    driver: bridge
```

### 6.4 docker-compose.override.yml (local — RAM réduite pour PC)

Si ton PC a moins de 16 Go de RAM, crée ce fichier pour réduire les allocations :

```yaml
# docker-compose.override.yml (pas commité, uniquement pour test local)
# Réduit la RAM pour tester sur un PC avec moins de ressources
services:
  hub-paper:
    environment:
      MEMORY: "512M"
  jeux-paper:
    environment:
      MEMORY: "1G"
  survie-neoforge:
    environment:
      MEMORY: "4G"
  dev-paper:
    environment:
      MEMORY: "768M"
```

### 6.5 Configuration Velocity

Au premier démarrage, Velocity génère ses fichiers de config dans `./data/velocity/`. Il faut ensuite éditer `velocity.toml` pour déclarer les serveurs backend.

```bash
# 1. Démarre le proxy seul pour générer la config
docker compose up -d proxy-velocity
# Attends ~10 secondes
docker compose logs proxy-velocity

# 2. Édite la config générée
nano ./data/velocity/velocity.toml
```

Modifie la section `[servers]` :

```toml
[servers]
  lobby = "ms-lobby:25565"
  jeux = "ms-jeux:25565"
  survie = "ms-survie:25565"
  dev = "ms-dev:25565"
  
  try = ["lobby"]

[forced-hosts]
  # Phase 2 — quand tu auras un domaine
  # "play.mineshark.fr" = ["lobby"]
```

**Important** : les noms `ms-lobby`, `ms-jeux`, etc. correspondent aux `container_name` dans le docker-compose. Docker résout ces noms en IP automatiquement via le réseau `mc-network`.

### 6.6 Forwarding secret (sécurité Velocity ↔ backends)

Velocity et les serveurs Paper doivent partager un secret pour se faire confiance. Sans ça, un joueur pourrait se connecter directement à un backend et usurper l'identité de n'importe qui.

```bash
# 1. Récupère le forwarding secret généré par Velocity
cat ./data/velocity/forwarding.secret
# Note la valeur (ex: "aBcDeFgH12345678")

# 2. Chaque serveur Paper doit avoir ce fichier :
# ./data/lobby/config/paper-global.yml
# ./data/jeux/config/paper-global.yml
# ./data/dev/config/paper-global.yml
```

Dans chaque `paper-global.yml`, vérifie/modifie :

```yaml
proxies:
  velocity:
    enabled: true
    online-mode: true
    secret: "aBcDeFgH12345678"   # Le même secret que Velocity
```

### 6.7 Lancer tout

```bash
# Démarre tous les services
docker compose up -d

# Surveille les logs (Ctrl+C pour quitter)
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f survie-neoforge

# Status
docker compose ps
```

### 6.8 Se connecter

| Édition | Adresse | Port |
|---------|---------|------|
| Java | `localhost` | 25565 |
| Bedrock | `localhost` | 19132 |

### 6.9 Commandes utiles

```bash
# Arrêter tout
docker compose down

# Arrêter tout + supprimer les données (repart de zéro)
docker compose down -v

# Redémarrer un service
docker compose restart survie-neoforge

# Shell dans un conteneur
docker compose exec ms-survie bash

# Console RCON (si activé)
docker compose exec ms-lobby rcon-cli
```

---

## 7. K3s — Installation

### 7.1 K3s sur WSL2 — Ce qu'il faut savoir

K3s fonctionne sur WSL2 mais nécessite **systemd activé**. Alternatives pour le dev local :

| Outil | Avantage | Inconvénient |
|-------|----------|-------------|
| **K3s natif** | Identique à la prod | Nécessite systemd, WSL2 spécifique |
| **k3d** | K3s dans Docker, rapide | Une couche d'abstraction en plus |
| **Kind** | Meilleure compat WSL2 | Plus lent que k3d |

**Recommandation** : k3d pour le dev local (plus simple), K3s natif sur le VPS.

### 7.2 Activer systemd dans WSL2

```bash
# Fichier /etc/wsl.conf
sudo tee /etc/wsl.conf << 'EOF'
[boot]
systemd=true
EOF

# Redémarre WSL2 depuis PowerShell
# wsl --shutdown
# Puis rouvre ton terminal WSL2
```

### 7.3 Option A — K3s natif (identique à la prod)

```bash
curl -sfL https://get.k3s.io | sh -

# Vérifie
sudo systemctl status k3s
sudo kubectl get nodes
# → le nœud doit être "Ready"

# Configure kubectl pour ton user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Alias
echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

# Test
k get nodes
```

### 7.4 Option B — k3d (K3s dans Docker, recommandé pour WSL2)

```bash
# Installe k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Crée un cluster
k3d cluster create mineshark \
  --port "25565:25565@loadbalancer" \
  --port "19132:19132/udp@loadbalancer"

# Installe kubectl si pas déjà fait
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# k3d configure automatiquement kubectl
kubectl get nodes
```

---

## 8. K3s — Concepts (comparaison Docker Compose)

Tu connais Docker Compose via Inception / ft_transcendence. Voici la traduction :

| Docker Compose | K8s/K3s | Rôle |
|----------------|---------|------|
| `services:` dans docker-compose.yml | **Deployment** (YAML) | Décrit quel conteneur lancer |
| `container_name:` | **Pod** | La plus petite unité d'exécution |
| `ports:` / `expose:` | **Service** (YAML) | Expose le conteneur sur le réseau |
| `volumes:` | **PVC** (PersistentVolumeClaim) | Stockage persistant |
| `.env` / `env_file:` | **ConfigMap** + **Secret** | Configuration + données sensibles |
| `restart: always` | Natif K8s | Redémarrage auto en cas de crash |
| `networks:` | Natif K8s (Flannel) | Réseau interne entre conteneurs |
| `docker compose up` | `kubectl apply -f` | Déployer |
| `docker compose down` | `kubectl delete -f` | Supprimer |
| `docker compose logs -f` | `kubectl logs -f` | Voir les logs |

**La grosse différence** : Docker Compose = 1 fichier. K8s = plusieurs fichiers YAML (un par aspect : conteneur, réseau, stockage). Plus verbeux mais chaque pièce est indépendante et modifiable séparément. K8s surveille en permanence que la réalité correspond à tes fichiers (réconciliation).

---

## 9. Manifestes K8s — Namespace & Secrets

### 9.1 Namespace

Fichier `k8s/base/namespace.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mineshark
  labels:
    app: mineshark
```

### 9.2 Secrets

```bash
# Forwarding secret — partagé entre Velocity et tous les backends
FORWARDING_SECRET=$(openssl rand -hex 16)
echo "Forwarding secret : $FORWARDING_SECRET"

kubectl create secret generic velocity-forwarding-secret \
  --namespace=mineshark \
  --from-literal=forwarding-secret="$FORWARDING_SECRET"

# RCON password — admin des serveurs à distance
RCON_PASS=$(openssl rand -base64 16)
echo "RCON password : $RCON_PASS"

kubectl create secret generic rcon-secret \
  --namespace=mineshark \
  --from-literal=rcon-password="$RCON_PASS"

# Clé API CurseForge — pour télécharger le modpack
kubectl create secret generic curseforge-api-key \
  --namespace=mineshark \
  --from-literal=api-key="TA_CLE_API"
```

### 9.3 Appliquer

```bash
kubectl apply -f k8s/base/namespace.yaml
```

---

## 10. Velocity — Proxy + GeyserMC + Floodgate

### 10.1 ConfigMap

Fichier `k8s/velocity/configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: velocity-config
  namespace: mineshark
data:
  velocity.toml: |
    bind = "0.0.0.0:25577"
    
    # Velocity vérifie les comptes Mojang (Java) et Xbox (Bedrock via Floodgate)
    # Les backends ont online-mode=false car Velocity a déjà vérifié
    online-mode = true
    
    [servers]
      lobby = "mc-lobby:25565"
      jeux = "mc-jeux:25565"
      survie = "mc-survie:25565"
      dev = "mc-dev:25565"
      try = ["lobby"]
    
    [forced-hosts]
      # Phase 2 — quand tu auras un domaine
      # "play.mineshark.fr" = ["lobby"]
    
    [advanced]
      compression-threshold = 256
      compression-level = -1
      login-ratelimit = 3000
      connection-timeout = 5000
      read-timeout = 30000
      haproxy-protocol = false
      tcp-fast-open = false
      bungee-plugin-message-channel = true
      show-ping-requests = false
      failover-on-unexpected-server-disconnect = true
      announce-proxy-commands = true
      log-command-executions = false
      log-player-connections = true
    
    [query]
      enabled = false
      port = 25577
```

### 10.2 PVC

Fichier `k8s/velocity/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: server-proxy-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

### 10.3 Deployment

Fichier `k8s/velocity/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velocity
  namespace: mineshark
  labels:
    app: velocity
    component: proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: velocity
  template:
    metadata:
      labels:
        app: velocity
        component: proxy
    spec:
      # Init container : télécharge les plugins avant le démarrage
      initContainers:
        - name: download-plugins
          image: busybox:1.36
          command: ['sh', '-c']
          args:
            - |
              echo "=== Downloading Velocity plugins ==="
              mkdir -p /server/plugins
              
              # GeyserMC — crossplay Bedrock → Java
              wget -O /server/plugins/Geyser-Velocity.jar \
                "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity"
              
              # Floodgate — auth Bedrock sans compte Java
              wget -O /server/plugins/Floodgate-Velocity.jar \
                "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity"
              
              echo "=== Plugins downloaded ==="
              ls -la /server/plugins/
          volumeMounts:
            - name: velocity-data
              mountPath: /server

      containers:
        - name: velocity
          image: itzg/mc-proxy:latest
          env:
            - name: TYPE
              value: "VELOCITY"
            - name: MEMORY
              value: "512m"
            - name: SERVER_PORT
              value: "25577"
          ports:
            - containerPort: 25577
              name: mc-java
              protocol: TCP
            - containerPort: 19132
              name: mc-bedrock
              protocol: UDP
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "768Mi"
              cpu: "1000m"
          readinessProbe:
            tcpSocket:
              port: 25577
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 25577
            initialDelaySeconds: 60
            periodSeconds: 30
          volumeMounts:
            - name: velocity-config
              mountPath: /server/velocity.toml
              subPath: velocity.toml
            - name: velocity-data
              mountPath: /server
      volumes:
        - name: velocity-config
          configMap:
            name: velocity-config
        - name: velocity-data
          persistentVolumeClaim:
            claimName: server-proxy-pvc
```

### 10.4 Service

Fichier `k8s/velocity/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: velocity
  namespace: mineshark
  labels:
    app: velocity
spec:
  type: NodePort
  selector:
    app: velocity
  ports:
    - name: minecraft-java
      port: 25577
      targetPort: 25577
      nodePort: 25565
      protocol: TCP
    - name: minecraft-bedrock
      port: 19132
      targetPort: 19132
      nodePort: 19132
      protocol: UDP
```

---

## 11. Lobby — Paper (Hub)

### 11.1 PVC

Fichier `k8s/lobby/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: server-lobby-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

### 11.2 Deployment

Fichier `k8s/lobby/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-lobby
  namespace: mineshark
  labels:
    app: mc-lobby
    component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mc-lobby
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mc-lobby
        component: server
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:latest
          env:
            - name: EULA
              value: "TRUE"
            - name: TYPE
              value: "PAPER"
            - name: VERSION
              value: "1.21.4"
            - name: MEMORY
              value: "1G"
            - name: USE_AIKAR_FLAGS
              value: "true"
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineShark §7- §eLobby"
            - name: MAX_PLAYERS
              value: "50"
            - name: DIFFICULTY
              value: "peaceful"
            - name: SPAWN_PROTECTION
              value: "16"
            - name: VIEW_DISTANCE
              value: "8"
            - name: SIMULATION_DISTANCE
              value: "6"
            - name: ENABLE_RCON
              value: "TRUE"
            - name: RCON_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: rcon-secret
                  key: rcon-password
            - name: PLUGINS
              value: "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
          ports:
            - containerPort: 25565
              name: minecraft
            - containerPort: 25575
              name: rcon
          resources:
            requests:
              memory: "1Gi"
              cpu: "250m"
            limits:
              memory: "1536Mi"
              cpu: "1500m"
          readinessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 60
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 120
            periodSeconds: 30
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: server-lobby-pvc
```

### 11.3 Service

Fichier `k8s/lobby/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-lobby
  namespace: mineshark
spec:
  type: ClusterIP
  selector:
    app: mc-lobby
  ports:
    - name: minecraft
      port: 25565
      targetPort: 25565
    - name: rcon
      port: 25575
      targetPort: 25575
```

---

## 12. Jeux — Paper (Plugins/Minijeux)

### 12.1 PVC

Fichier `k8s/jeux/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: server-plugins-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 15Gi
```

### 12.2 Deployment

Fichier `k8s/jeux/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-jeux
  namespace: mineshark
  labels:
    app: mc-jeux
    component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mc-jeux
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mc-jeux
        component: server
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:latest
          env:
            - name: EULA
              value: "TRUE"
            - name: TYPE
              value: "PAPER"
            - name: VERSION
              value: "1.21.4"
            - name: MEMORY
              value: "2G"
            - name: USE_AIKAR_FLAGS
              value: "true"
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineShark §7- §aJeux & Plugins"
            - name: MAX_PLAYERS
              value: "50"
            - name: DIFFICULTY
              value: "normal"
            - name: VIEW_DISTANCE
              value: "10"
            - name: SIMULATION_DISTANCE
              value: "8"
            - name: ENABLE_RCON
              value: "TRUE"
            - name: RCON_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: rcon-secret
                  key: rcon-password
            - name: PLUGINS
              value: "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
          ports:
            - containerPort: 25565
            - containerPort: 25575
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
            limits:
              memory: "2560Mi"
              cpu: "2000m"
          readinessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 60
            periodSeconds: 10
          livenessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 120
            periodSeconds: 30
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: server-plugins-pvc
```

### 12.3 Service

Fichier `k8s/jeux/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-jeux
  namespace: mineshark
spec:
  type: ClusterIP
  selector:
    app: mc-jeux
  ports:
    - name: minecraft
      port: 25565
      targetPort: 25565
    - name: rcon
      port: 25575
      targetPort: 25575
```

---

## 13. Survie — NeoForge (Modded Together)

### 13.1 Le modpack

- **Nom** : Modded Together
- **CurseForge** : https://www.curseforge.com/minecraft/modpacks/moddedtogether
- **Slug** : `moddedtogether` (sans tiret)
- **Mod loader** : NeoForge
- **Version MC** : 1.21.1
- **Type** : RPG, magie, tech, quêtes, exploration (fantasy-driven)
- **RAM recommandée** : 6 Go minimum (modpack lourd, 150+ mods)

### 13.2 Clé API CurseForge

Depuis les restrictions Overwolf (propriétaire de CurseForge), le téléchargement automatique des modpacks nécessite une API key.

1. https://console.curseforge.com/ → créer un compte
2. Générer une API key
3. La stocker dans le Secret K8s (section 9.2) ou dans `.env` (Docker Compose)

### 13.3 PVC

Fichier `k8s/survie/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: server-modded-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### 13.4 Deployment

Fichier `k8s/survie/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-survie
  namespace: mineshark
  labels:
    app: mc-survie
    component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mc-survie
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mc-survie
        component: server
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:latest
          env:
            - name: EULA
              value: "TRUE"
            - name: TYPE
              value: "AUTO_CURSEFORGE"
            - name: CF_SLUG
              value: "moddedtogether"
            - name: CF_API_KEY
              valueFrom:
                secretKeyRef:
                  name: curseforge-api-key
                  key: api-key
            # 6 Go de Heap — ligne de flottaison pour 150+ mods
            - name: MEMORY
              value: "6G"
            - name: USE_AIKAR_FLAGS
              value: "true"
            - name: ONLINE_MODE
              value: "FALSE"
            - name: MOTD
              value: "§b§lMineShark §7- §cSurvie Modee"
            - name: MAX_PLAYERS
              value: "30"
            - name: DIFFICULTY
              value: "hard"
            - name: VIEW_DISTANCE
              value: "8"
            - name: SIMULATION_DISTANCE
              value: "6"
            - name: ENABLE_RCON
              value: "TRUE"
            - name: RCON_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: rcon-secret
                  key: rcon-password
          ports:
            - containerPort: 25565
            - containerPort: 25575
          resources:
            requests:
              memory: "6Gi"
              cpu: "1000m"
            limits:
              memory: "7Gi"
              cpu: "4000m"
          # Timeouts plus longs — le modpack met 3-5 min à démarrer
          readinessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 180
            periodSeconds: 15
          livenessProbe:
            exec:
              command: ["mc-health"]
            initialDelaySeconds: 300
            periodSeconds: 30
            failureThreshold: 5
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: server-modded-pvc
```

### 13.5 Service

Fichier `k8s/survie/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-survie
  namespace: mineshark
spec:
  type: ClusterIP
  selector:
    app: mc-survie
  ports:
    - name: minecraft
      port: 25565
      targetPort: 25565
    - name: rcon
      port: 25575
      targetPort: 25575
```

### 13.6 Note crossplay modé

Les joueurs Bedrock **ne peuvent pas** accéder au serveur modé via GeyserMC (les mods sont incompatibles avec le protocole Bedrock). Hydraulic (beta de GeyserMC) peut aider pour les mods simples (items, blocs) mais pas les mods complexes. C'est une limite technique fondamentale.

Les joueurs Java avec le modpack installé (Prism Launcher, CurseForge App) peuvent naviguer entre lobby, jeux et survie via Velocity sans quitter MC.

---

## 14. Dev — Paper (Sandbox)

### 14.1 PVC

Fichier `k8s/dev/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: server-sandbox-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 14.2 Deployment

Fichier `k8s/dev/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-dev
  namespace: mineshark
  labels:
    app: mc-dev
    component: server
    environment: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mc-dev
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: mc-dev
        component: server
        environment: dev
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:latest
          env:
            - name: EULA
              value: "TRUE"
            - name: TYPE
              value: "PAPER"
            - name: VERSION
              value: "1.21.4"
            - name: MEMORY
              value: "1500m"
            - name: USE_AIKAR_FLAGS
              value: "true"
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineShark §7- §aDev §c[UNSTABLE]"
            - name: MAX_PLAYERS
              value: "10"
            - name: DIFFICULTY
              value: "peaceful"
            - name: GAMEMODE
              value: "creative"
            - name: ENABLE_RCON
              value: "TRUE"
            - name: RCON_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: rcon-secret
                  key: rcon-password
            - name: PLUGINS
              value: "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
          ports:
            - containerPort: 25565
            - containerPort: 25575
          resources:
            requests:
              memory: "1536Mi"
              cpu: "250m"
            limits:
              memory: "2Gi"
              cpu: "1500m"
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: server-sandbox-pvc
```

### 14.3 Service

Fichier `k8s/dev/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-dev
  namespace: mineshark
spec:
  type: ClusterIP
  selector:
    app: mc-dev
  ports:
    - name: minecraft
      port: 25565
      targetPort: 25565
    - name: rcon
      port: 25575
      targetPort: 25575
```

### 14.4 Allumer / Éteindre le dev

```bash
# Éteindre (économise ~2 Go de RAM)
kubectl -n mineshark scale deployment/mc-dev --replicas=0

# Allumer
kubectl -n mineshark scale deployment/mc-dev --replicas=1
```

---

## 15. Routage Réseau — Traefik TCP/UDP

### 15.1 Le problème

K3s inclut Traefik comme Ingress Controller. Par défaut, Traefik ne gère que HTTP/HTTPS (ports 80/443). Minecraft utilise TCP brut (port 25565) et UDP brut (port 19132) — il faut dire à Traefik d'écouter sur ces ports.

### 15.2 Deux approches

| Approche | Complexité | Quand l'utiliser |
|----------|-----------|-----------------|
| **NodePort** (section 10.4) | Simple | 1 seul VPS, ça marche direct |
| **Traefik IngressRoute** | Complexe | Multi-nœud, routage avancé, domaines multiples |

**Pour MineShark** : NodePort suffit. Si plus tard tu ajoutes un 2ème VPS ou du routage par domaine, tu migreras vers IngressRoute.

### 15.3 Configuration Traefik (si tu choisis IngressRoute)

Fichier à placer sur l'hôte VPS dans `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml` :

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    ports:
      minecraft-tcp:
        port: 25565
        expose:
          default: true
        exposedPort: 25565
        protocol: TCP
      minecraft-udp:
        port: 19132
        expose:
          default: true
        exposedPort: 19132
        protocol: UDP
    additionalArguments:
      - "--entryPoints.minecraft-tcp.address=:25565/tcp"
      - "--entryPoints.minecraft-udp.address=:19132/udp"
```

Puis les routes :

```yaml
# k8s/traefik/ingress-routes.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: route-minecraft-java
  namespace: mineshark
spec:
  entryPoints:
    - minecraft-tcp
  routes:
    - match: HostSNI(`*`)
      services:
        - name: velocity
          port: 25577
---
apiVersion: traefik.io/v1alpha1
kind: IngressRouteUDP
metadata:
  name: route-minecraft-bedrock
  namespace: mineshark
spec:
  entryPoints:
    - minecraft-udp
  routes:
    - services:
        - name: velocity
          port: 19132
```

**Note** : `HostSNI(*)` est obligatoire car le protocole MC n'envoie pas d'info de domaine au niveau TCP. La discrimination par domaine se fait au niveau Velocity (couche 7 du protocole MC, pas de la couche réseau).

**Important** : ne modifie JAMAIS le deployment Traefik directement dans le cluster — K3s le réécrasera au prochain redémarrage. Utilise toujours le `HelmChartConfig`.

---

## 16. TCPShield — Protection DDoS & DNS

### 16.1 Pourquoi ?

TCPShield est un reverse proxy Anycast gratuit spécialisé Minecraft. Il masque l'IP du VPS, filtre les attaques DDoS (SYN floods, UDP amplification), et vérifie l'authentification des joueurs.

### 16.2 Setup

1. Crée un compte sur https://tcpshield.com (gratuit)
2. Crée un "Network" → "Mineshark"
3. Ajoute ton backend : `IP_DU_VPS:25565`
4. TCPShield te donne un **CNAME**

### 16.3 DNS

Achète un domaine (ex: `mineshark.fr`) chez Cloudflare, Gandi, ou OVH (~5-10€/an).

```
play.mineshark.fr    CNAME    ton-id.tcpshield.com    # Jeu (via TCPShield)
mineshark.fr         A        X.X.X.X                  # Site web (direct)
www.mineshark.fr     CNAME    mineshark.fr              # Redirect www
```

### 16.4 Plugin Velocity

Le plugin TCPShield est téléchargé dans l'init container de Velocity (section 10.3). Il remplace l'IP de TCPShield par la vraie IP du joueur dans les logs et plugins.

---

## 17. Site Web — Architecture prévue (Phase 3)

### Stack

| Service | Rôle | Port |
|---------|------|------|
| Next.js | Frontend + SSR | 3000 |
| NestJS | API backend + WebSocket | 4000 |
| PostgreSQL | BDD (joueurs, stats, auth) | 5432 |

### Ingress Traefik (HTTP/HTTPS)

```yaml
# k8s/web/ingress.yaml — Phase 3
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mineshark-web
  namespace: mineshark-web
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: mineshark.fr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 3000
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 4000
  tls:
    - hosts:
        - mineshark.fr
      secretName: mineshark-tls
```

Traefik remplace Nginx — il gère le SSL automatiquement via Let's Encrypt. Pas besoin d'installer Nginx.

---

## 18. Structure du Repo GitHub

```
mineshark/
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Deploy auto sur push main
│       ├── backup.yml              # Backup quotidien
│       └── lint.yml                # Validation YAML sur PR
├── k8s/
│   ├── base/
│   │   └── namespace.yaml
│   ├── velocity/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   ├── lobby/
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   ├── jeux/
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   ├── survie/
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   ├── dev/
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   ├── traefik/
│   │   └── ingress-routes.yaml     # Optionnel (si pas NodePort)
│   └── web/                         # Phase 3
│       ├── namespace.yaml
│       ├── ingress.yaml
│       ├── frontend.yaml
│       ├── backend.yaml
│       └── postgres.yaml
├── configs/
│   └── velocity/
│       └── velocity.toml
├── scripts/
│   ├── setup-vps.sh
│   ├── backup.sh
│   └── restore.sh
├── docker-compose.yml               # Test local
├── docker-compose.override.yml      # Overrides locaux (pas commité)
├── .env.example
├── Makefile
├── .gitignore
└── README.md
```

### .gitignore

```gitignore
# Secrets
*.secret
*.key
kubeconfig*
.env
.env.*
!.env.example

# Données Minecraft
data/
world/
world_nether/
world_the_end/
*.jar
logs/
crash-reports/

# Docker
docker-compose.override.yml

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Node (site web Phase 3)
node_modules/
.next/
dist/
```

---

## 19. Makefile

```makefile
# ============================================================
#  MineShark — Makefile
# ============================================================

.PHONY: help setup deploy deploy-all status logs backup \
        start-dev stop-dev restart scale shell rcon clean \
        local-up local-down local-logs

NAMESPACE    := mineshark
KUBECTL      := kubectl -n $(NAMESPACE)

# === AIDE ===
help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================================
#  LOCAL (Docker Compose)
# ============================================================

local-up: ## Lance les serveurs en local (Docker Compose)
	docker compose up -d

local-down: ## Arrete les serveurs locaux
	docker compose down

local-logs: ## Logs des serveurs locaux
	docker compose logs -f

local-ps: ## Status des serveurs locaux
	docker compose ps

# ============================================================
#  K3S — SETUP
# ============================================================

setup: ## Setup initial : namespace + secrets
	@echo "=== Creation du namespace ==="
	kubectl apply -f k8s/base/namespace.yaml
	@echo ""
	@echo "=== Creation des secrets ==="
	@FSECRET=$$(openssl rand -hex 16) && \
		echo "Forwarding secret: $$FSECRET" && \
		kubectl create secret generic velocity-forwarding-secret \
			--namespace=$(NAMESPACE) \
			--from-literal=forwarding-secret="$$FSECRET" \
			--dry-run=client -o yaml | kubectl apply -f -
	@RPASS=$$(openssl rand -base64 16) && \
		echo "RCON password: $$RPASS" && \
		kubectl create secret generic rcon-secret \
			--namespace=$(NAMESPACE) \
			--from-literal=rcon-password="$$RPASS" \
			--dry-run=client -o yaml | kubectl apply -f -
	@echo "=== Setup OK ==="

setup-cf-key: ## Configure la cle API CurseForge (make setup-cf-key KEY=xxx)
	@if [ -z "$(KEY)" ]; then echo "Usage: make setup-cf-key KEY=ta_cle"; exit 1; fi
	kubectl create secret generic curseforge-api-key \
		--namespace=$(NAMESPACE) \
		--from-literal=api-key="$(KEY)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "=== Cle CurseForge OK ==="

# ============================================================
#  K3S — DEPLOIEMENT
# ============================================================

deploy-all: ## Deploie TOUS les composants K3s
	kubectl apply -f k8s/base/
	kubectl apply -f k8s/velocity/
	kubectl apply -f k8s/lobby/
	kubectl apply -f k8s/jeux/
	kubectl apply -f k8s/survie/
	kubectl apply -f k8s/dev/

deploy: ## Deploie un composant (make deploy C=velocity)
	@if [ -z "$(C)" ]; then echo "Usage: make deploy C=velocity|lobby|jeux|survie|dev"; exit 1; fi
	kubectl apply -f k8s/base/
	kubectl apply -f k8s/$(C)/

# ============================================================
#  K3S — STATUS & MONITORING
# ============================================================

status: ## Etat de tous les pods et services
	@echo "--- PODS ---"
	@$(KUBECTL) get pods -o wide
	@echo ""
	@echo "--- SERVICES ---"
	@$(KUBECTL) get svc
	@echo ""
	@echo "--- PVC ---"
	@$(KUBECTL) get pvc
	@echo ""
	@echo "--- RAM/CPU ---"
	@$(KUBECTL) top pods 2>/dev/null || echo "(metrics-server non installe)"

logs: ## Logs d'un serveur (make logs S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make logs S=velocity|mc-lobby|mc-jeux|mc-survie|mc-dev"; exit 1; fi
	$(KUBECTL) logs -f deployment/$(S)

events: ## Derniers evenements K8s
	$(KUBECTL) get events --sort-by='.lastTimestamp' | tail -30

# ============================================================
#  K3S — GESTION
# ============================================================

restart: ## Redemarre un serveur (make restart S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make restart S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout restart deployment/$(S)

start-dev: ## Allume le serveur dev
	$(KUBECTL) scale deployment/mc-dev --replicas=1

stop-dev: ## Eteint le serveur dev (economise ~2 Go RAM)
	$(KUBECTL) scale deployment/mc-dev --replicas=0

scale: ## Scale un deployment (make scale S=mc-dev R=0)
	@if [ -z "$(S)" ] || [ -z "$(R)" ]; then echo "Usage: make scale S=mc-dev R=0"; exit 1; fi
	$(KUBECTL) scale deployment/$(S) --replicas=$(R)

shell: ## Shell dans un serveur (make shell S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make shell S=mc-lobby"; exit 1; fi
	$(KUBECTL) exec -it deployment/$(S) -- bash

rcon: ## Console RCON (make rcon S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make rcon S=mc-lobby"; exit 1; fi
	$(KUBECTL) exec -it deployment/$(S) -- rcon-cli

players: ## Liste les joueurs connectes
	@for server in mc-lobby mc-jeux mc-survie mc-dev; do \
		RESULT=$$($(KUBECTL) exec deployment/$$server -- rcon-cli list 2>/dev/null | head -1) ; \
		echo "  $$server: $$RESULT" ; \
	done

# ============================================================
#  BACKUP
# ============================================================

backup: ## Backup tous les mondes
	@mkdir -p backups
	@DATE=$$(date +%Y-%m-%d_%H-%M) && \
	for server in mc-lobby mc-jeux mc-survie; do \
		echo "Backing up $$server..." ; \
		$(KUBECTL) exec deployment/$$server -- \
			tar czf /tmp/backup.tar.gz /data/world /data/world_nether /data/world_the_end 2>/dev/null && \
		POD=$$($(KUBECTL) get pod -l app=$$server -o jsonpath='{.items[0].metadata.name}') && \
		$(KUBECTL) cp $(NAMESPACE)/$$POD:/tmp/backup.tar.gz backups/$$server-$$DATE.tar.gz && \
		echo "  -> backups/$$server-$$DATE.tar.gz" || \
		echo "  -> $$server skipped" ; \
	done

backup-clean: ## Supprime les backups > 7 jours
	find backups/ -name "*.tar.gz" -mtime +7 -delete

# ============================================================
#  ROLLBACK & DEBUG
# ============================================================

rollback: ## Rollback (make rollback S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make rollback S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout undo deployment/$(S)

history: ## Historique des deployments (make history S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make history S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout history deployment/$(S)

describe: ## Details d'un pod (make describe S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make describe S=mc-lobby"; exit 1; fi
	$(KUBECTL) describe pod -l app=$(S)

# ============================================================
#  NETTOYAGE
# ============================================================

clean-dev: ## Supprime le serveur dev
	$(KUBECTL) delete -f k8s/dev/ --ignore-not-found

clean-all: ## DANGER : Supprime TOUT le namespace
	@echo "ATTENTION : supprime TOUS les serveurs et donnees"
	@read -p "Tape 'mineshark' pour confirmer : " confirm && \
		[ "$$confirm" = "mineshark" ] && \
		kubectl delete namespace $(NAMESPACE) || \
		echo "Annule."
```

---

## 20. CI/CD — GitHub Actions

### 20.1 Secrets GitHub

Repository → Settings → Secrets → Actions :

| Secret | Valeur |
|--------|--------|
| `VPS_HOST` | IP du VPS |
| `VPS_USER` | `mineshark` |
| `VPS_SSH_KEY` | Contenu de `~/.ssh/id_ed25519` |
| `KUBECONFIG_DATA` | `cat ~/.kube/config | base64 -w 0` |

### 20.2 Deploy

Fichier `.github/workflows/deploy.yml` :

```yaml
name: Deploy Mineshark

on:
  push:
    branches: [main]
    paths: ['k8s/**', 'configs/**']
  workflow_dispatch:
    inputs:
      component:
        description: 'Component (all, velocity, lobby, jeux, survie, dev)'
        required: true
        default: 'all'

jobs:
  validate:
    name: Validate YAML
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install kubeval
        run: |
          wget -q https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
          tar xf kubeval-linux-amd64.tar.gz
          sudo mv kubeval /usr/local/bin/
      - name: Validate
        run: find k8s/ -name "*.yaml" | xargs kubeval --strict || true

  deploy:
    name: Deploy
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Setup kubectl
        run: |
          curl -sLO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl && sudo mv kubectl /usr/local/bin/
      - name: Configure kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_DATA }}" | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config
      - name: Deploy
        run: |
          C="${{ github.event.inputs.component || 'all' }}"
          kubectl apply -f k8s/base/
          if [ "$C" = "all" ]; then
            for dir in velocity lobby jeux survie dev; do
              kubectl apply -f k8s/$dir/
            done
          else
            kubectl apply -f k8s/$C/
          fi
      - name: Verify
        run: kubectl -n mineshark get pods
```

### 20.3 Lint

Fichier `.github/workflows/lint.yml` :

```yaml
name: Lint
on:
  pull_request:
    branches: [main]
jobs:
  yaml-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install yamllint
      - run: yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" k8s/
```

### 20.4 Backup

Fichier `.github/workflows/backup.yml` :

```yaml
name: Backup
on:
  schedule:
    - cron: '0 4 * * *'
  workflow_dispatch:

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: SSH Backup
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.VPS_SSH_KEY }}" > ~/.ssh/key
          chmod 600 ~/.ssh/key
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts
          ssh -i ~/.ssh/key ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} \
            'cd ~/mineshark && make backup && make backup-clean'
```

---

## 21. Optimisations — JVM, Pregen, Monitoring

### 21.1 Aikar's Flags (tuning JVM)

`USE_AIKAR_FLAGS=true` dans l'image itzg active automatiquement les drapeaux de tuning du Garbage Collector G1GC. Ces flags :

- Synchronisent `-Xms` et `-Xmx` (évite le redimensionnement dynamique du Heap — très coûteux en CPU)
- Ajustent `G1HeapRegionSize` selon la RAM allouée
- Augmentent le ratio de la zone de génération d'objets récents (NewRatio)
- Réduisent les pauses "Stop-The-World" du GC qui causent le lag

**C'est non négociable** — sans Aikar's flags, le serveur modé va stutterer (saccader) à chaque cycle de ramasse-miettes.

### 21.2 Prégénération avec Chunky

Quand un joueur explore des zones non générées, le serveur doit calculer le terrain en temps réel (bruit de Perlin 3D, placement des minerais, structures, biomes custom des mods). Sur un VPS partagé, ça peut écrouler le TPS (Ticks Per Second — le serveur vise 20 TPS constants).

**Solution** : prégénérer un rayon de 5000 blocs autour du spawn **avant** d'ouvrir au public.

```bash
# Installe le mod/plugin Chunky sur le serveur survie
# Puis dans la console RCON :
chunky radius 5000
chunky start
# Attend que ça finisse (peut prendre 1-2h sur VPS)
```

Après prégénération, les joueurs ne font que lire des chunks déjà calculés depuis le disque NVMe — infiniment moins coûteux que la génération en temps réel.

### 21.3 Monitoring

```bash
# Commandes rapides (K3s)
make status          # Pods, services, PVC, RAM/CPU
make logs S=mc-survie   # Logs temps réel
make players         # Joueurs connectés
make events          # Événements K8s (debug)

# Docker Compose (local)
make local-ps        # Status
make local-logs      # Logs
```

Phase 3 : Prometheus + Grafana pour le monitoring avancé (dashboards temps réel, alertes).

---

## 22. Setup VPS Production (Debian 12)

### 22.1 Commander le VPS

Sur Contabo (https://contabo.com) :
- **Plan** : Cloud VPS 30
- **OS** : Debian 12 (Bookworm)
- **Localisation** : Europe (Munich, Allemagne)
- **IPv4 + IPv6** : les deux

### 22.2 Première connexion et sécurisation

```bash
# Connecte-toi en root
ssh root@X.X.X.X

# Mises à jour
apt update && apt upgrade -y

# Création utilisateur
adduser mineshark
usermod -aG sudo mineshark

# Clé SSH pour le nouvel user
mkdir -p /home/mineshark/.ssh
cp /root/.ssh/authorized_keys /home/mineshark/.ssh/
chown -R mineshark:mineshark /home/mineshark/.ssh
chmod 700 /home/mineshark/.ssh
chmod 600 /home/mineshark/.ssh/authorized_keys

# Sécurisation SSH
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Firewall
apt install -y ufw
ufw allow OpenSSH
ufw allow 25565/tcp    # Minecraft Java
ufw allow 19132/udp    # Minecraft Bedrock
ufw allow 443/tcp      # HTTPS (site web)
ufw allow 80/tcp       # HTTP (redirect)
ufw allow 6443/tcp     # K3s API
ufw enable

# Outils
apt install -y curl wget git htop nano unzip make

exit
```

### 22.3 Installer K3s

```bash
ssh mineshark@X.X.X.X

curl -sfL https://get.k3s.io | sh -
sudo systemctl status k3s

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

k get nodes
```

### 22.4 Déployer

```bash
cd ~
git clone https://github.com/zoyern/mineshark.git
cd mineshark

make setup
make setup-cf-key KEY=ta_cle_api_curseforge
make deploy-all
make status
```

---

## 23. FAQ

### Pourquoi `itzg/mc-proxy` et pas `itzg/minecraft-server` pour Velocity ?

Ce sont deux images différentes. `itzg/mc-proxy` est conçue pour les proxys (Velocity, BungeeCord, Waterfall). `itzg/minecraft-server` est pour les serveurs de jeu (Paper, NeoForge, Vanilla, etc.). Utiliser la mauvaise image = ça ne démarre pas.

### online-mode true ou false ?

`online-mode=true` sur **Velocity uniquement**. Les backends ont `online-mode=false` car Velocity a déjà vérifié l'auth. Le forwarding secret garantit la confiance entre proxy et backends.

### PurPur vs Paper ?

PurPur est un fork de Paper avec plus de boutons de config gameplay (vitesse des entités, hauteur de build, etc.). Paper est plus documenté et stable. Switcher plus tard = changer `TYPE=PURPUR` dans l'env, zéro migration de données.

### Les backends ne sont pas exposés ?

Non. Ils sont en `ClusterIP` (réseau interne K8s uniquement). Seul Velocity a un `NodePort` exposé à l'extérieur. Impossible de contourner l'auth en se connectant directement à un backend.

### Les joueurs peuvent passer de modé à vanilla ?

Oui via Velocity (`/server lobby`, `/server jeux`, ou clic sur un NPC). Mais le client doit avoir les mods installés pour aller sur le serveur modé. Un client vanilla sera kick du serveur modé. Un client modé peut aller partout.

### Les joueurs Bedrock peuvent aller sur le serveur modé ?

Non. Les mods sont incompatibles avec le protocole Bedrock. Les joueurs Bedrock ne peuvent accéder qu'aux serveurs Paper (lobby, jeux, dev).

### CF_SLUG — c'est quoi exactement ?

Le slug c'est l'identifiant du modpack dans l'URL CurseForge : `curseforge.com/minecraft/modpacks/moddedtogether` → slug = `moddedtogether`. L'image itzg l'utilise pour télécharger automatiquement le modpack via l'API CurseForge.

---

## 24. Roadmap

### Phase 1 — Infrastructure (maintenant)
- [ ] Test Docker Compose en local (WSL2)
- [ ] Valider que les 4 serveurs communiquent via Velocity
- [ ] Commander Contabo VPS 30
- [ ] Setup Debian 12 + K3s
- [ ] Déployer les manifestes K8s
- [ ] CI/CD GitHub Actions
- [ ] Backups automatiques
- [ ] DNS + domaine mineshark.fr
- [ ] TCPShield

### Phase 2 — Plugins & Gameplay
- [ ] Plugins lobby (portails, NPC : Citizens + CommandNPC)
- [ ] Plugins essentiels (EssentialsX, LuckPerms, WorldGuard)
- [ ] Minijeux sur le serveur jeux
- [ ] Prégénération Chunky sur la survie
- [ ] Tester Hydraulic (crossplay modé Bedrock — beta)

### Phase 3 — Site Web
- [ ] Next.js frontend + NestJS backend + PostgreSQL
- [ ] Auth (lien compte MC ↔ compte site)
- [ ] Dashboard joueurs (stats, classements)
- [ ] Panel admin (RCON web, gestion serveurs via API K8s)
- [ ] Monitoring (Prometheus + Grafana)

### Phase 4 — Extras
- [ ] Launcher custom MineShark (SKCraft Launcher)
- [ ] Alertes Discord (serveur down, backup fail)
- [ ] Bot Discord
- [ ] Skywars repensé avec vos anciennes maps

---

## 25. Sources & Références

### Docker / Images
- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) — image Docker MC (Paper, NeoForge, etc.)
- [itzg/docker-mc-proxy](https://github.com/itzg/docker-mc-proxy) — image Docker proxy (Velocity, BungeeCord)
- [itzg MC Server Docs](https://docker-minecraft-server.readthedocs.io/) — documentation complète
- [AUTO_CURSEFORGE Docs](https://docker-minecraft-server.readthedocs.io/en/latest/types-and-platforms/mod-platforms/auto-curseforge/)

### Serveur MC
- [PaperMC](https://papermc.io/) — serveur Paper
- [PurpurMC](https://purpurmc.org/) — fork Paper avec plus de config
- [Velocity](https://papermc.io/software/velocity/) — proxy MC moderne
- [NeoForge](https://neoforged.net/) — mod loader (fork Forge)

### Crossplay
- [GeyserMC](https://geysermc.org/) — crossplay Java/Bedrock
- [GeyserMC Hydraulic](https://github.com/GeyserMC/Hydraulic) — crossplay modé (beta)

### K8s
- [K3s Docs](https://docs.k3s.io/) — K3s officiel
- [k3d](https://k3d.io/) — K3s dans Docker (dev local)
- [Traefik](https://traefik.io/) — ingress controller

### VPS
- [Contabo](https://contabo.com/) — VPS (recommandé)
- [Netcup](https://www.netcup.com/) — VPS CPU dédié

### Sécurité
- [TCPShield](https://tcpshield.com/) — anti-DDoS MC gratuit

### Modpack
- [Modded Together — CurseForge](https://www.curseforge.com/minecraft/modpacks/moddedtogether)

### Launcher
- [SKCraft Launcher](https://github.com/SKCraft/Launcher) — launcher custom
- [Prism Launcher](https://prismlauncher.org/) — launcher open source

### JVM Tuning
- [Aikar's Flags](https://docs.papermc.io/paper/aikars-flags) — tuning GC pour MC
