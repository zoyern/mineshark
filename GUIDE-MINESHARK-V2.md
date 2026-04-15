# Guide Mineshark v2 — Infrastructure Minecraft Complète

> Guide détaillé pour monter un réseau Minecraft (modé + vanilla + plugins + dev) avec K3s, Docker, CI/CD, crossplay Java/Bedrock, TCPShield, et Makefile.
> Dernière mise à jour : 12 avril 2026

---

## Table des matières

1. [Architecture Globale](#1-architecture-globale)
2. [Choix du VPS — Comparatif Vérifié](#2-choix-du-vps--comparatif-vérifié)
3. [Setup Initial du VPS (Debian 12)](#3-setup-initial-du-vps-debian-12)
4. [Docker — Les Bases (pour comprendre K3s)](#4-docker--les-bases-pour-comprendre-k3s)
5. [K3s — Installation & Concepts](#5-k3s--installation--concepts)
6. [Velocity — Le Proxy Minecraft](#6-velocity--le-proxy-minecraft)
7. [TCPShield — Protection DDoS & DNS](#7-tcpshield--protection-ddos--dns)
8. [Serveur Lobby (Paper)](#8-serveur-lobby-paper)
9. [Serveur Jeux/Plugins (Paper)](#9-serveur-jeuxplugins-paper)
10. [Serveur Survie Modé (NeoForge — Modded Together)](#10-serveur-survie-modé-neoforge--modded-together)
11. [Crossplay Java + Bedrock (GeyserMC + Floodgate + Hydraulic)](#11-crossplay-java--bedrock-geysermc--floodgate--hydraulic)
12. [Serveur Dev/Sandbox](#12-serveur-devsandbox)
13. [Site Web — Architecture (Next.js + NestJS + PostgreSQL)](#13-site-web--architecture-nextjs--nestjs--postgresql)
14. [Structure du Repo GitHub](#14-structure-du-repo-github)
15. [Makefile — Automatisation](#15-makefile--automatisation)
16. [CI/CD avec GitHub Actions](#16-cicd-avec-github-actions)
17. [Monitoring & Backups](#17-monitoring--backups)
18. [Commandes Utiles K3s](#18-commandes-utiles-k3s)
19. [Setup Local (WSL2) — Dev sans VPS](#19-setup-local-wsl2--dev-sans-vps)
20. [FAQ & Concepts Expliqués](#20-faq--concepts-expliqués)
21. [Roadmap & Phases](#21-roadmap--phases)

---

## 1. Architecture Globale

### Schéma du réseau

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
┌─────────────────────────────────────────────────┐
│              VPS (Contabo/Netcup)                │
│            Debian 12 + K3s Cluster               │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Traefik Ingress (port 443 HTTPS)          │  │  ← Site web
│  │  inclus avec K3s, auto SSL Let's Encrypt   │  │
│  └──────────────┬─────────────────────────────┘  │
│                 │                                 │
│  ┌──────────────▼─────────────────────────────┐  │
│  │  Site Web                                   │  │
│  │  ┌──────────┐ ┌───────────┐ ┌──────────┐  │  │
│  │  │ Next.js  │ │ NestJS    │ │PostgreSQL│  │  │
│  │  │ Frontend │ │ Backend   │ │   DB     │  │  │
│  │  │ :3000    │ │ :4000     │ │ :5432    │  │  │
│  │  └──────────┘ └───────────┘ └──────────┘  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │         Velocity Proxy                      │  │
│  │   + GeyserMC (crossplay Bedrock)           │  │
│  │   + Floodgate (auth Bedrock sans Java)     │  │
│  │   + TCPShield Plugin                        │  │
│  │   Ports: 25565/TCP (Java), 19132/UDP (BE)  │  │
│  └─────┬──────────┬──────────┬───────────┬────┘  │
│        │          │          │           │        │
│   ┌────▼────┐┌────▼────┐┌───▼─────┐┌────▼────┐  │
│   │ lobby   ││ jeux    ││ survie  ││  dev    │  │
│   │ Paper   ││ Paper   ││NeoForge ││ Paper   │  │
│   │ :25566  ││ :25567  ││ :25568  ││ :25569  │  │
│   │         ││plugins  ││ Modded  ││sandbox  │  │
│   │ hub     ││minijeux ││Together ││ test    │  │
│   │ portails││ pvp     ││+Hydraul ││         │  │
│   └─────────┘└─────────┘└─────────┘└─────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Volumes Persistants (PVC K3s)              │  │
│  │  server-proxy/  server-lobby/               │  │
│  │  server-plugins/ server-modded/             │  │
│  │  server-sandbox/ postgres-data/             │  │
│  │  backups/                                   │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### Les 4 serveurs Minecraft

| Serveur | Logiciel | Rôle | RAM | Crossplay Bedrock |
|---------|----------|------|-----|-------------------|
| **lobby** | Paper | Hub d'arrivée, portails, NPC de navigation | 1 GB | Oui (GeyserMC) |
| **jeux** | Paper | Minijeux, PvP, survie vanilla, maps custom, plugins | 2 GB | Oui (GeyserMC) |
| **survie** | NeoForge | Modded Together + Hydraulic (beta) | 5 GB | Partiel (Hydraulic) |
| **dev** | Paper | Sandbox de test, peut crash sans affecter le reste | 1.5 GB | Oui (GeyserMC) |

### Pourquoi Paper et pas Purpur ?

Paper est le standard actuel (fork optimisé de Spigot, 40-60% plus rapide). Purpur ajoute de la customisation gameplay en plus. On commence avec Paper car plus documenté et stable. Si tu veux switcher plus tard, c'est une seule ligne à changer (`TYPE=PURPUR`), zéro migration.

### Composants infrastructure

| Composant | Rôle | Détail |
|-----------|------|--------|
| **Velocity** | Proxy Minecraft | Point d'entrée unique, route les joueurs vers les bons serveurs. Les joueurs naviguent entre serveurs sans quitter Minecraft. |
| **GeyserMC** | Crossplay | Traduit le protocole Bedrock (UDP) en Java (TCP). Les joueurs mobile/console/Windows 10 peuvent rejoindre. |
| **Floodgate** | Auth Bedrock | Permet aux joueurs Bedrock de se connecter sans compte Java payé. |
| **Hydraulic** | Crossplay modé | Mod compagnon de Geyser pour que Bedrock accède aux serveurs modés (beta). |
| **TCPShield** | Anti-DDoS | Proxy réseau qui masque l'IP du VPS. Gratuit pour petits serveurs. |
| **K3s** | Orchestrateur | Kubernetes léger (~60 MB). Gère tous les conteneurs, redémarrages, réseau interne. |
| **Traefik** | Ingress web | Reverse proxy HTTP/HTTPS inclus dans K3s. Gère le site web + SSL automatique. |

### TCP vs UDP — pourquoi ?

Java Edition utilise **TCP** (port 25565) : fiable, chaque paquet arrive dans l'ordre. Choix historique de Mojang (2011) pour la cohérence du monde.

Bedrock Edition utilise **UDP** (port 19132) : plus rapide, moins de latence. Conçu pour mobile/console où le réseau est instable. Perdre quelques paquets vaut mieux qu'un lag spike qui bloque tout.

C'est codé dans les jeux, on ne peut pas changer.

---

## 2. Choix du VPS — Comparatif Vérifié

### Besoins en RAM estimés

| Service | RAM |
|---------|-----|
| Debian 12 + K3s + Traefik | ~1.2 GB |
| Velocity + GeyserMC + Floodgate | ~512 MB |
| Lobby (Paper) | ~1 GB |
| Serveur Jeux (Paper) | ~2 GB |
| Survie Modée (NeoForge) | ~5 GB |
| Dev Sandbox (Paper) — éteint quand pas utilisé | ~1.5 GB |
| Site web (Next.js + NestJS) | ~512 MB |
| PostgreSQL | ~256 MB |
| **Total (tout actif)** | **~12 GB** |
| **Total (dev éteint)** | **~10.5 GB** |

**Conclusion : 16 GB minimum.** Avec 8 GB c'est impossible de tout faire tourner.

### Comparatif VPS Europe (avril 2026, post-augmentation Hetzner)

| Provider | Plan | vCPU | RAM | SSD | Prix/mois | DDoS Protection | Note |
|----------|------|------|-----|-----|-----------|-----------------|------|
| **Contabo** | Cloud VPS 2 | 6 shared | **16 GB** | 400 GB NVMe | **~13€** | Basique | Best RAM/€, perf CPU variable |
| **Netcup** | RS 2000 G12 | 8 **dédiés** | **16 GB** | 512 GB NVMe | **~17€** | Oui | CPU dédié AMD EPYC, excellent pour MC |
| Hetzner | CX42 | 8 shared | 16 GB | 160 GB | ~21-22€ | Oui | Ex-roi, trop cher post-augmentation |
| Hetzner | CX32 | 4 shared | 8 GB | 80 GB | ~11-12€ | Oui | Pas assez de RAM |
| OVH | VPS Essential | 4 shared | 8 GB | 80 GB | ~10€ | Oui | Pas assez de RAM |

### Recommandations

**Budget serré (< 15€)** → **Contabo Cloud VPS 2** (~13€)
- 16 GB de RAM, 400 GB de stockage
- CPU partagé (perf variable sous charge)
- Datacenter Munich (Allemagne)

**Budget confortable (< 20€)** → **Netcup RS 2000 G12** (~17€)
- 16 GB de RAM, 512 GB NVMe
- **CPU DÉDIÉ AMD EPYC** — crucial pour Minecraft qui est mono-thread intensif
- Datacenter Nuremberg (Allemagne)

**Ma recommandation** : **Netcup RS 2000** si tu peux mettre 17€. Le CPU dédié fait une vraie différence pour Minecraft. Sinon Contabo à 13€.

### Note sur Vultr

Vultr facture les instances **même stoppées**. L'idée de destroy/recreate via Terraform pour économiser est techniquement faisable mais pas viable pour un serveur de jeu (5-10 min de boot, les joueurs ne peuvent pas se connecter pendant ce temps, complexité de restauration des données). Par contre, K3s permet déjà d'éteindre le serveur dev avec `kubectl scale --replicas=0` — c'est gratuit et instantané.

### Note sur Infomaniak

Infomaniak est excellent pour le web hosting et la vie privée (Suisse, écolo). Mais pour du bare metal / VPS gaming avec Docker/K3s, Contabo et Netcup sont devant en perf brute par euro.

---

## 3. Setup Initial du VPS (Debian 12)

### 3.1 Commander le VPS

Sur Contabo ou Netcup :
- **OS** : Debian 12 (Bookworm) — plus léger et stable qu'Ubuntu
- **Location** : Allemagne (Munich/Nuremberg — proches de la France)
- **IPv4 + IPv6** : les deux (IPv6 est standard, certains joueurs Bedrock mobile n'ont que de l'IPv6)

### 3.2 Générer une clé SSH (sur ta machine locale)

```bash
# Si tu n'as pas de clé SSH
ssh-keygen -t ed25519 -C "alexis@mineshark"

# Affiche ta clé publique → à coller dans le panneau du VPS
cat ~/.ssh/id_ed25519.pub
```

### 3.3 Première connexion et sécurisation

```bash
# Connecte-toi en root
ssh root@X.X.X.X

# === Mises à jour ===
apt update && apt upgrade -y

# === Création utilisateur ===
adduser mineshark
usermod -aG sudo mineshark

# === Clé SSH pour le nouvel user ===
mkdir -p /home/mineshark/.ssh
cp /root/.ssh/authorized_keys /home/mineshark/.ssh/
chown -R mineshark:mineshark /home/mineshark/.ssh
chmod 700 /home/mineshark/.ssh
chmod 600 /home/mineshark/.ssh/authorized_keys

# === Sécurisation SSH ===
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# === Firewall ===
apt install -y ufw
ufw allow OpenSSH
ufw allow 25565/tcp    # Minecraft Java (Velocity)
ufw allow 19132/udp    # Minecraft Bedrock (GeyserMC)
ufw allow 443/tcp      # HTTPS (site web via Traefik)
ufw allow 80/tcp       # HTTP (redirect vers HTTPS)
ufw allow 6443/tcp     # K3s API (kubectl distant)
ufw enable

# === Outils de base ===
apt install -y curl wget git htop nano unzip make

# === Déconnexion ===
exit
```

### 3.4 Reconnexion avec ton user

```bash
ssh mineshark@X.X.X.X
```

---

## 4. Docker — Les Bases (pour comprendre K3s)

### Pourquoi parler de Docker si on utilise K3s ?

K3s utilise **containerd** en interne — c'est le moteur de conteneurs qui est aussi sous Docker. Comprendre Docker aide à comprendre ce que K3s fait sous le capot. On installe Docker pour les tests locaux et le build d'images, mais en production c'est K3s qui gère tout.

### 4.1 Installer Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker mineshark

# Déconnecte/reconnecte pour activer le groupe
exit
# Re-SSH...

# Test
docker --version
docker run hello-world
```

### 4.2 Concepts Docker (comparaison avec ton Transcendance)

Tu connais déjà le Dockerfile grâce à Inception. Voici le lien avec K8s :

| Docker Compose (ton Transcendance) | K8s/K3s (Mineshark) | Rôle |
|-------------------------------------|----------------------|------|
| `services:` dans docker-compose.yml | **Deployment** (fichier YAML) | Décrit quel conteneur lancer et comment |
| `ports:` / `expose:` | **Service** (fichier YAML) | Expose le conteneur sur le réseau |
| `volumes:` en bas du fichier | **PVC** (PersistentVolumeClaim) | Stockage persistant |
| `.env` / `env_file:` | **ConfigMap** + **Secret** | Configuration et données sensibles |
| `depends_on:` | K8s gère automatiquement | Ordre de démarrage |
| `restart: always` | K8s le fait nativement | Restart en cas de crash |
| `networks:` | K8s le fait nativement | Réseau interne entre conteneurs |
| `docker compose up` | `kubectl apply -f` | Lancer le tout |
| `docker compose down` | `kubectl delete -f` | Arrêter le tout |

**La grosse différence** : Docker Compose = 1 fichier. K8s = plusieurs fichiers YAML, chacun décrivant un aspect (le conteneur, le réseau, le stockage). C'est plus verbeux mais chaque pièce est indépendante et modifiable séparément. Et K8s surveille en permanence que la réalité correspond à tes fichiers.

### 4.3 Test rapide — lancer un serveur MC avec Docker

Juste pour comprendre. On ne garde pas ça.

```bash
mkdir -p ~/docker-test && cd ~/docker-test

# Lance un serveur Paper
docker run -d \
  --name mc-test \
  -p 25565:25565 \
  -e EULA=TRUE \
  -e TYPE=PAPER \
  -e VERSION=1.21.4 \
  -e MEMORY=1G \
  -v mc-test-data:/data \
  itzg/minecraft-server

# Regarde les logs
docker logs -f mc-test    # Ctrl+C pour quitter

# Nettoie tout
docker stop mc-test && docker rm mc-test && docker volume rm mc-test-data
```

---

## 5. K3s — Installation & Concepts

### 5.1 K3s vs K8s — la vraie différence

| | K3s | K8s (complet) |
|--|-----|---------------|
| Taille | ~60 MB | ~300 MB+ |
| Installation | 1 commande | Complexe (kubeadm, etcd, etc.) |
| Base de données | SQLite | etcd (lourd) |
| Cas d'usage | 1-5 serveurs, edge, IoT, apprentissage | Clusters d'entreprise, multi-cloud |
| API/YAML | 100% compatible K8s | Standard |
| Inclus | Traefik, Flannel, CoreDNS, local-path | Rien, tout à installer |

Tout ce que tu apprends sur K3s est **directement transposable** à K8s. Les fichiers YAML sont identiques.

Il n'existe pas de K4s, K5s, etc. Le nom "K3s" est un jeu de mots : K8s = K + 8 lettres + s, K3s = moitié de K8s. Il existe **K0s** (autre distro légère de Kubernetes) mais K3s est la plus populaire.

### 5.2 Concepts K8s essentiels

| Concept | Analogie Docker Compose | Explication |
|---------|------------------------|-------------|
| **Namespace** | — | Un espace isolé. On crée `mineshark` pour séparer nos trucs du système. |
| **Pod** | Un `service:` | La plus petite unité. 1 Pod = 1 conteneur = 1 serveur MC. |
| **Deployment** | La section d'un service | Décrit combien de Pods, quelle image, quelles variables. Gère updates/rollbacks. |
| **Service** | `ports:` / `expose:` | Donne un nom DNS stable à un Pod. `mc-lobby:25565` fonctionne dans le cluster. |
| **PVC** | `volumes:` | Demande de stockage persistant. Les mondes MC survivent aux redémarrages. |
| **ConfigMap** | `.env` | Configuration non-sensible (velocity.toml, server.properties). |
| **Secret** | `.env` mais chiffré | Données sensibles (mots de passe RCON, forwarding secret, clés API). |
| **Ingress** | Nginx avec `ports: "443:443"` | Route le trafic HTTP/HTTPS vers les bons services. Traefik fait ça automatiquement. |

### 5.3 Installation K3s

```bash
# Installe K3s (1 commande !)
curl -sfL https://get.k3s.io | sh -

# Vérifie
sudo systemctl status k3s
sudo kubectl get nodes
# → ton nœud doit être "Ready"
```

### 5.4 Configurer kubectl pour ton user

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Alias pratique
echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

# Test
k get nodes
```

### 5.5 Accès kubectl depuis ta machine locale (WSL2)

```bash
# Sur ta machine locale / WSL2
# Installe kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Copie le kubeconfig depuis le VPS
scp mineshark@X.X.X.X:~/.kube/config ~/.kube/config-mineshark

# Remplace 127.0.0.1 par l'IP publique
sed -i 's/127.0.0.1/X.X.X.X/' ~/.kube/config-mineshark

export KUBECONFIG=~/.kube/config-mineshark
kubectl get nodes
```

---

## 6. Velocity — Le Proxy Minecraft

Velocity c'est le "petit serveur proxy" dont tu te souvenais (BungeeCord). C'est le successeur moderne, 8x plus performant et bien plus sécurisé.

### 6.1 Créer la structure

```bash
mkdir -p ~/mineshark/k8s/{base,velocity,lobby,jeux,survie,dev,web}
```

### 6.2 Namespace

Fichier `~/mineshark/k8s/base/namespace.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mineshark
  labels:
    app: mineshark
```

```bash
kubectl apply -f ~/mineshark/k8s/base/namespace.yaml
```

### 6.3 Secrets partagés

```bash
# Forwarding secret — partagé entre Velocity et tous les backends
# C'est le mot de passe interne pour que les serveurs se fassent confiance
FORWARDING_SECRET=$(openssl rand -hex 16)
echo "Forwarding secret : $FORWARDING_SECRET"

kubectl create secret generic velocity-forwarding-secret \
  --namespace=mineshark \
  --from-literal=forwarding-secret="$FORWARDING_SECRET"

# RCON password — pour administrer les serveurs à distance
RCON_PASS=$(openssl rand -base64 16)
echo "RCON password : $RCON_PASS"

kubectl create secret generic rcon-secret \
  --namespace=mineshark \
  --from-literal=rcon-password="$RCON_PASS"
```

### 6.4 ConfigMap Velocity

Fichier `~/mineshark/k8s/velocity/configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: velocity-config
  namespace: mineshark
data:
  velocity.toml: |
    # === Velocity Configuration ===
    
    # Adresse d'écoute interne
    bind = "0.0.0.0:25577"
    
    # Mode online : Velocity vérifie les comptes Mojang (Java)
    # Les serveurs backend ont online-mode=false car Velocity a déjà vérifié
    # Les joueurs Bedrock passent par Floodgate (pas besoin de compte Java)
    online-mode = true
    
    # Les 4 serveurs backend
    [servers]
      lobby = "mc-lobby:25565"
      jeux = "mc-jeux:25565"
      survie = "mc-survie:25565"
      dev = "mc-dev:25565"
      
      # Serveur par défaut à la connexion
      try = ["lobby"]
    
    [forced-hosts]
      # Avec un domaine (Phase 2) :
      # "play.mineshark.fr" = ["lobby"]
      # "jeux.mineshark.fr" = ["jeux"]
    
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
      # Query = protocole GameSpy4, permet aux sites web de récupérer
      # des infos (joueurs, MOTD). Désactivé car :
      # - Vecteur d'attaque DDoS
      # - Redondant (RCON + API K8s font mieux)
      # - Ton site web utilisera RCON ou l'API K8s
      enabled = false
      port = 25577
```

### 6.5 PVC Velocity

Fichier `~/mineshark/k8s/velocity/pvc.yaml` :

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

### 6.6 Deployment Velocity

Fichier `~/mineshark/k8s/velocity/deployment.yaml` :

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
              
              # GeyserMC — crossplay Bedrock
              wget -O /server/plugins/Geyser-Velocity.jar \
                "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity"
              
              # Floodgate — auth Bedrock sans compte Java
              wget -O /server/plugins/Floodgate-Velocity.jar \
                "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity"
              
              # TCPShield — protection DDoS (plugin Velocity)
              wget -O /server/plugins/TCPShield.jar \
                "https://github.com/TCPShield/RealIP/releases/latest/download/TCPShield-1.0-SNAPSHOT.jar" || \
                echo "WARN: TCPShield download failed, check URL"
              
              echo "=== Plugins downloaded ==="
              ls -la /server/plugins/
          volumeMounts:
            - name: velocity-data
              mountPath: /server

      containers:
        - name: velocity
          # L'image s'appelle itzg/bungeecord mais avec TYPE=VELOCITY
          # elle installe et lance Velocity (pas BungeeCord)
          # C'est juste un nom d'image historique
          image: itzg/bungeecord:latest
          env:
            - name: TYPE
              value: "VELOCITY"
            - name: MEMORY
              value: "512m"
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
              memory: "1Gi"
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

### 6.7 Service Velocity

Fichier `~/mineshark/k8s/velocity/service.yaml` :

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
    # Java : les joueurs se connectent sur le port 25565 (externe)
    # qui est routé vers 25577 (interne Velocity)
    - name: minecraft-java
      port: 25577
      targetPort: 25577
      nodePort: 25565
      protocol: TCP
    # Bedrock : port standard 19132 (UDP)
    - name: minecraft-bedrock
      port: 19132
      targetPort: 19132
      nodePort: 19132
      protocol: UDP
```

### 6.8 Déployer

```bash
kubectl apply -f ~/mineshark/k8s/velocity/

kubectl -n mineshark get pods
kubectl -n mineshark logs -f deployment/velocity
```

---

## 7. TCPShield — Protection DDoS & DNS

### 7.1 Pourquoi TCPShield ?

TCPShield est un proxy réseau gratuit spécialisé Minecraft. Il masque l'IP de ton VPS, protège contre les DDoS (SYN floods, UDP amplification), et met en cache le MOTD pour économiser de la bande passante.

### 7.2 Setup

1. Crée un compte sur https://tcpshield.com (gratuit)
2. Crée un "Network" → entre le nom "Mineshark"
3. Ajoute ton backend : `IP_DU_VPS:25565`
4. TCPShield te donne un **CNAME** à configurer sur ton domaine

### 7.3 DNS

1. Achète un domaine (ex: `mineshark.fr`) chez Cloudflare, Gandi, ou OVH (~5-10€/an)
2. Configure le DNS :
   - **Pour le jeu** : Enregistrement SRV ou CNAME pointant vers TCPShield
   - **Pour le site web** : Enregistrement A pointant vers l'IP du VPS

Avec Hetzner DNS (gratuit, jusqu'à 25 zones) ou directement chez ton registrar.

```
# Exemple DNS
play.mineshark.fr    CNAME    ton-id.tcpshield.com    # Jeu MC (via TCPShield)
mineshark.fr         A        X.X.X.X                  # Site web (direct)
www.mineshark.fr     CNAME    mineshark.fr              # Redirect www
```

### 7.4 Plugin Velocity

Le plugin TCPShield est téléchargé automatiquement par l'init container du deployment Velocity. Il remplace les IP des joueurs par leurs vraies IP (sinon Velocity verrait l'IP de TCPShield pour tout le monde).

---

## 8. Serveur Lobby (Paper)

Le hub d'arrivée. Les joueurs s'y connectent en premier et naviguent vers les autres serveurs via des portails ou des NPC.

### 8.1 PVC

Fichier `~/mineshark/k8s/lobby/pvc.yaml` :

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

### 8.2 Deployment

Fichier `~/mineshark/k8s/lobby/deployment.yaml` :

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
            # online-mode FALSE car c'est Velocity qui gère l'auth
            - name: ONLINE_MODE
              value: "FALSE"
            # Secret partagé avec Velocity pour la confiance interne
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineshark §7- §eLobby"
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
            # Auto-download Floodgate pour que les skins Bedrock marchent
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

### 8.3 Service

Fichier `~/mineshark/k8s/lobby/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-lobby
  namespace: mineshark
spec:
  type: ClusterIP    # Accessible uniquement dans le cluster (via Velocity)
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

## 9. Serveur Jeux/Plugins (Paper)

Le vrai serveur de gameplay : minijeux, PvP, survie vanilla, maps custom.

### 9.1 PVC

Fichier `~/mineshark/k8s/jeux/pvc.yaml` :

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

### 9.2 Deployment

Fichier `~/mineshark/k8s/jeux/deployment.yaml` :

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
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineshark §7- §aJeux & Plugins"
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

### 9.3 Service

Fichier `~/mineshark/k8s/jeux/service.yaml` :

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

## 10. Serveur Survie Modé (NeoForge — Modded Together)

### 10.1 Clé API CurseForge

L'image `itzg/minecraft-server` peut télécharger automatiquement les modpacks CurseForge. Il faut une API key.

1. Va sur https://console.curseforge.com/
2. Crée un compte / connecte-toi
3. Génère une API key

```bash
kubectl create secret generic curseforge-api-key \
  --namespace=mineshark \
  --from-literal=api-key="TON_API_KEY_ICI"
```

### 10.2 PVC

Fichier `~/mineshark/k8s/survie/pvc.yaml` :

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

### 10.3 Deployment

Fichier `~/mineshark/k8s/survie/deployment.yaml` :

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
            # Modpack CurseForge — auto-download
            - name: MOD_PLATFORM
              value: "AUTO_CURSEFORGE"
            - name: CF_SLUG
              value: "moddedtogether"
            - name: CF_API_KEY
              valueFrom:
                secretKeyRef:
                  name: curseforge-api-key
                  key: api-key
            # Performance — JVM flags optimisés pour modpacks
            - name: MEMORY
              value: "5G"
            - name: JVM_XX_OPTS
              value: >-
                -XX:+UseG1GC -XX:+ParallelRefProcEnabled
                -XX:MaxGCPauseMillis=200
                -XX:+UnlockExperimentalVMOptions
                -XX:+DisableExplicitGC -XX:+AlwaysPreTouch
                -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40
                -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20
                -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4
                -XX:InitiatingHeapOccupancyPercent=15
                -XX:G1MixedGCLiveThresholdPercent=90
                -XX:G1RSetUpdatingPauseTimePercent=5
                -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem
                -XX:MaxTenuringThreshold=1
            - name: ONLINE_MODE
              value: "FALSE"
            - name: MOTD
              value: "§b§lMineshark §7- §cSurvie Modee"
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
              memory: "5Gi"
              cpu: "1000m"
            limits:
              memory: "6Gi"
              cpu: "4000m"
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

### 10.4 Service

Fichier `~/mineshark/k8s/survie/service.yaml` :

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

### 10.5 Note sur le crossplay modé

Les joueurs Bedrock ne pourront **pas** accéder au serveur modé via GeyserMC standard (les mods sont incompatibles). Hydraulic (beta) peut aider pour les mods simples (items, blocs), mais pas les mods complexes. On prépare l'archi pour l'ajouter plus tard.

Les joueurs Java avec le modpack installé (via Prism Launcher, CurseForge, ou ton futur launcher custom) peuvent naviguer librement entre le lobby, les jeux et la survie sans quitter Minecraft grâce à Velocity.

---

## 11. Crossplay Java + Bedrock (GeyserMC + Floodgate + Hydraulic)

### Résumé de ce qui est déjà en place

- **GeyserMC** : installé sur Velocity (init container), écoute UDP 19132
- **Floodgate** : installé sur Velocity + chaque serveur Paper (variable PLUGINS)
- **online-mode=true** sur Velocity : vérifie les comptes Mojang (Java) et Xbox (Bedrock via Floodgate)

### Configuration GeyserMC

Après premier démarrage, édite si besoin :

```bash
kubectl -n mineshark exec -it deployment/velocity -- sh
cat /server/plugins/Geyser-Velocity/config.yml
```

Les valeurs importantes :

```yaml
bedrock:
  address: 0.0.0.0
  port: 19132
  motd1: "Mineshark"
  motd2: "Java + Bedrock"
remote:
  address: auto
  port: 25577
  auth-type: floodgate    # Bedrock utilise Floodgate, pas de compte Java nécessaire
```

### Connexion pour les joueurs

| Edition | Adresse | Port |
|---------|---------|------|
| Java | play.mineshark.fr (ou IP) | 25565 (TCP) |
| Bedrock | play.mineshark.fr (ou IP) | 19132 (UDP) |

### Hydraulic (Phase 2)

Quand tu voudras tester le crossplay modé :
1. Télécharge Hydraulic depuis https://github.com/GeyserMC/Hydraulic
2. Ajoute-le comme mod sur le serveur NeoForge
3. Teste la compatibilité mod par mod

---

## 12. Serveur Dev/Sandbox

### 12.1 PVC

Fichier `~/mineshark/k8s/dev/pvc.yaml` :

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

### 12.2 Deployment

Fichier `~/mineshark/k8s/dev/deployment.yaml` :

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
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineshark §7- §aDev §c[UNSTABLE]"
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

### 12.3 Service

Fichier `~/mineshark/k8s/dev/service.yaml` :

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

### 12.4 Éteindre / Allumer le dev

```bash
# Éteindre (économise ~1.5 GB de RAM)
kubectl -n mineshark scale deployment/mc-dev --replicas=0

# Allumer
kubectl -n mineshark scale deployment/mc-dev --replicas=1
```

### 12.5 Sandbox modée (plus tard)

Pour tester des mods sans casser la survie, tu pourras ajouter un 5e serveur `mc-dev-modded` en copiant le deployment survie et en changeant le nom + PVC. L'archi K3s rend ça trivial.

---

## 13. Site Web — Architecture (Next.js + NestJS + PostgreSQL)

### Prévue pour Phase 3, mais on prépare l'archi maintenant.

L'idée : un namespace `mineshark-web` avec 3 services, exposés via Traefik (déjà inclus dans K3s).

```yaml
# ~/mineshark/k8s/web/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mineshark-web
```

### Stack prévue

| Service | Rôle | Port interne |
|---------|------|-------------|
| Next.js | Frontend + SSR | 3000 |
| NestJS | API backend + WebSocket | 4000 |
| PostgreSQL | Base de données (joueurs, stats, auth site) | 5432 |

### Ingress (comment ça remplace Nginx)

```yaml
# ~/mineshark/k8s/web/ingress.yaml — Exemple pour plus tard
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mineshark-web-ingress
  namespace: mineshark-web
  annotations:
    # Traefik gère les certificats SSL automatiquement via Let's Encrypt
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

Traefik remplace Nginx — il écoute sur le port 443, gère le SSL automatiquement, et route `/` vers Next.js et `/api` vers NestJS. Pas besoin d'installer Nginx.

---

## 14. Structure du Repo GitHub

```
mineshark/
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Deploy auto sur push main
│       ├── backup.yml              # Backup quotidien des mondes
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
│   └── web/                        # Phase 3
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
├── docs/
│   ├── ARCHITECTURE.md
│   └── COMMANDS.md
├── Makefile                         # Automatisation
├── .gitignore
└── README.md
```

### .gitignore

```gitignore
# Secrets — JAMAIS dans Git
*.secret
*.key
kubeconfig*
.env
.env.*

# Données Minecraft
world/
world_nether/
world_the_end/
*.jar
logs/
crash-reports/

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Node (site web)
node_modules/
.next/
dist/
```

---

## 15. Makefile — Automatisation

Fichier `Makefile` à la racine du repo :

```makefile
# ============================================================
#  Mineshark — Makefile
#  Automatisation des commandes K3s, Docker, et maintenance
# ============================================================

.PHONY: help setup deploy deploy-all status logs backup \
        start-dev stop-dev restart scale shell rcon clean

# === Variables ===
NAMESPACE    := mineshark
KUBECTL      := kubectl -n $(NAMESPACE)

# === Aide ===
help: ## Affiche cette aide
	@echo ""
	@echo "  🦈 Mineshark — Commandes disponibles"
	@echo "  ======================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ============================================================
#  SETUP
# ============================================================

setup: ## Setup initial : namespace + secrets
	@echo "=== Création du namespace ==="
	kubectl apply -f k8s/base/namespace.yaml
	@echo ""
	@echo "=== Création des secrets ==="
	@echo "Forwarding secret :"
	@FSECRET=$$(openssl rand -hex 16) && \
		echo "  $$FSECRET" && \
		kubectl create secret generic velocity-forwarding-secret \
			--namespace=$(NAMESPACE) \
			--from-literal=forwarding-secret="$$FSECRET" \
			--dry-run=client -o yaml | kubectl apply -f -
	@echo ""
	@echo "RCON password :"
	@RPASS=$$(openssl rand -base64 16) && \
		echo "  $$RPASS" && \
		kubectl create secret generic rcon-secret \
			--namespace=$(NAMESPACE) \
			--from-literal=rcon-password="$$RPASS" \
			--dry-run=client -o yaml | kubectl apply -f -
	@echo ""
	@echo "=== Setup terminé ==="

setup-cf-key: ## Configure la clé API CurseForge (usage: make setup-cf-key KEY=xxx)
	@if [ -z "$(KEY)" ]; then echo "Usage: make setup-cf-key KEY=ta_cle_api"; exit 1; fi
	kubectl create secret generic curseforge-api-key \
		--namespace=$(NAMESPACE) \
		--from-literal=api-key="$(KEY)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "=== Clé CurseForge configurée ==="

# ============================================================
#  DÉPLOIEMENT
# ============================================================

deploy-all: ## Déploie TOUS les composants
	@echo "=== Deploying all components ==="
	kubectl apply -f k8s/base/
	kubectl apply -f k8s/velocity/
	kubectl apply -f k8s/lobby/
	kubectl apply -f k8s/jeux/
	kubectl apply -f k8s/survie/
	kubectl apply -f k8s/dev/
	@echo "=== Done ==="

deploy: ## Déploie un composant (usage: make deploy C=velocity)
	@if [ -z "$(C)" ]; then echo "Usage: make deploy C=velocity|lobby|jeux|survie|dev"; exit 1; fi
	kubectl apply -f k8s/base/
	kubectl apply -f k8s/$(C)/
	@echo "=== $(C) deployed ==="

# ============================================================
#  STATUS & MONITORING
# ============================================================

status: ## Affiche l'état de tous les pods et services
	@echo ""
	@echo "  🦈 MINESHARK STATUS — $$(date)"
	@echo "  =================================="
	@echo ""
	@echo "--- PODS ---"
	@$(KUBECTL) get pods -o wide
	@echo ""
	@echo "--- SERVICES ---"
	@$(KUBECTL) get svc
	@echo ""
	@echo "--- PVC (Stockage) ---"
	@$(KUBECTL) get pvc
	@echo ""
	@echo "--- RAM / CPU ---"
	@$(KUBECTL) top pods 2>/dev/null || echo "(metrics-server pas installé)"
	@echo ""

logs: ## Logs d'un serveur (usage: make logs S=mc-lobby)
	@if [ -z "$(S)" ]; then \
		echo "Usage: make logs S=velocity|mc-lobby|mc-jeux|mc-survie|mc-dev"; \
		exit 1; \
	fi
	$(KUBECTL) logs -f deployment/$(S)

events: ## Derniers événements K8s (utile pour debug)
	$(KUBECTL) get events --sort-by='.lastTimestamp' | tail -30

# ============================================================
#  GESTION DES SERVEURS
# ============================================================

restart: ## Redémarre un serveur (usage: make restart S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make restart S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout restart deployment/$(S)
	@echo "=== $(S) restarting ==="

start-dev: ## Allume le serveur dev/sandbox
	$(KUBECTL) scale deployment/mc-dev --replicas=1
	@echo "=== Dev server starting ==="

stop-dev: ## Éteint le serveur dev/sandbox (économise ~1.5 GB RAM)
	$(KUBECTL) scale deployment/mc-dev --replicas=0
	@echo "=== Dev server stopped ==="

scale: ## Scale un deployment (usage: make scale S=mc-dev R=0)
	@if [ -z "$(S)" ] || [ -z "$(R)" ]; then \
		echo "Usage: make scale S=mc-dev R=0"; exit 1; \
	fi
	$(KUBECTL) scale deployment/$(S) --replicas=$(R)

shell: ## Ouvre un shell dans un serveur (usage: make shell S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make shell S=mc-lobby"; exit 1; fi
	$(KUBECTL) exec -it deployment/$(S) -- bash

rcon: ## Ouvre la console RCON (usage: make rcon S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make rcon S=mc-lobby"; exit 1; fi
	$(KUBECTL) exec -it deployment/$(S) -- rcon-cli

players: ## Liste les joueurs sur chaque serveur
	@echo ""
	@echo "  🦈 Joueurs connectés"
	@echo "  ===================="
	@for server in mc-lobby mc-jeux mc-survie mc-dev; do \
		RESULT=$$($(KUBECTL) exec deployment/$$server -- rcon-cli list 2>/dev/null | head -1) ; \
		echo "  $$server: $$RESULT" ; \
	done
	@echo ""

# ============================================================
#  BACKUP & RESTORE
# ============================================================

backup: ## Backup tous les mondes
	@echo "=== Backup des mondes ==="
	@mkdir -p backups
	@DATE=$$(date +%Y-%m-%d_%H-%M) && \
	for server in mc-lobby mc-jeux mc-survie; do \
		echo "Backing up $$server..." ; \
		$(KUBECTL) exec deployment/$$server -- \
			tar czf /tmp/backup.tar.gz /data/world /data/world_nether /data/world_the_end 2>/dev/null && \
		POD=$$($(KUBECTL) get pod -l app=$$server -o jsonpath='{.items[0].metadata.name}') && \
		$(KUBECTL) cp $(NAMESPACE)/$$POD:/tmp/backup.tar.gz backups/$$server-$$DATE.tar.gz && \
		echo "  -> backups/$$server-$$DATE.tar.gz" || \
		echo "  -> $$server backup skipped" ; \
	done
	@echo "=== Backup terminé ==="

backup-clean: ## Supprime les backups de plus de 7 jours
	find backups/ -name "*.tar.gz" -mtime +7 -delete
	@echo "=== Old backups cleaned ==="

# ============================================================
#  ROLLBACK & DEBUG
# ============================================================

rollback: ## Rollback un deployment (usage: make rollback S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make rollback S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout undo deployment/$(S)
	@echo "=== $(S) rolled back ==="

history: ## Historique des déploiements (usage: make history S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make history S=mc-lobby"; exit 1; fi
	$(KUBECTL) rollout history deployment/$(S)

describe: ## Détails d'un pod (usage: make describe S=mc-lobby)
	@if [ -z "$(S)" ]; then echo "Usage: make describe S=mc-lobby"; exit 1; fi
	$(KUBECTL) describe pod -l app=$(S)

# ============================================================
#  DEV LOCAL (WSL2)
# ============================================================

local-install-k3s: ## Installe K3s en local (WSL2)
	curl -sfL https://get.k3s.io | sh -
	@echo "=== K3s installé ==="
	@echo "Configure kubectl :"
	@echo "  mkdir -p ~/.kube"
	@echo "  sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config"
	@echo "  sudo chown \$$(id -u):\$$(id -g) ~/.kube/config"

local-setup: setup deploy-all ## Setup complet en local
	@echo "=== Local setup done ==="

# ============================================================
#  NETTOYAGE
# ============================================================

clean-dev: ## Supprime le serveur dev et ses données
	$(KUBECTL) delete -f k8s/dev/ --ignore-not-found
	@echo "=== Dev server cleaned ==="

clean-all: ## DANGER : Supprime TOUT le namespace mineshark
	@echo "⚠️  ATTENTION : Ceci va supprimer TOUS les serveurs et données !"
	@read -p "Tape 'mineshark' pour confirmer : " confirm && \
		[ "$$confirm" = "mineshark" ] && \
		kubectl delete namespace $(NAMESPACE) || \
		echo "Annulé."
```

---

## 16. CI/CD avec GitHub Actions

### 16.1 Secrets GitHub à configurer

Repository → Settings → Secrets → Actions :

| Secret | Valeur |
|--------|--------|
| `VPS_HOST` | IP du VPS |
| `VPS_USER` | `mineshark` |
| `VPS_SSH_KEY` | Contenu de `~/.ssh/id_ed25519` |
| `KUBECONFIG_DATA` | `cat ~/.kube/config \| base64 -w 0` |

### 16.2 Deploy workflow

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

### 16.3 Lint workflow

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

### 16.4 Backup workflow

Fichier `.github/workflows/backup.yml` :

```yaml
name: Backup
on:
  schedule:
    - cron: '0 4 * * *'    # Tous les jours à 4h UTC
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
          ssh -i ~/.ssh/key ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} 'cd ~/mineshark && make backup && make backup-clean'
```

### 16.5 Flow de travail quotidien

```bash
# Tu modifies un deployment
git checkout -b feat/add-pvp-plugin
nano k8s/jeux/deployment.yaml

# Commit + push
git add k8s/jeux/deployment.yaml
git commit -m "feat(jeux): add PvP plugin"
git push origin feat/add-pvp-plugin

# Crée une PR → lint.yml vérifie les YAML
# Merge → deploy.yml déploie automatiquement
```

---

## 17. Monitoring & Backups

### Commandes rapides (ou via Makefile)

```bash
make status          # État complet
make logs S=mc-survie   # Logs en temps réel
make players         # Joueurs connectés
make events          # Événements K8s (debug)
make backup          # Backup manuel
```

---

## 18. Commandes Utiles K3s

```bash
# === PODS ===
k -n mineshark get pods                    # Lister
k -n mineshark describe pod <NOM>          # Détails (debug)
k -n mineshark logs <NOM> --previous       # Logs d'un pod crashé

# === SERVEURS MC ===
make shell S=mc-lobby                       # Shell dans le conteneur
make rcon S=mc-survie                       # Console RCON
make restart S=mc-jeux                      # Redémarrer

# === DÉPLOIEMENTS ===
make history S=mc-lobby                     # Historique
make rollback S=mc-lobby                    # Retour version précédente
make scale S=mc-dev R=0                     # Éteindre le dev

# === STOCKAGE ===
k -n mineshark get pvc                     # Voir les volumes
k -n mineshark exec deployment/mc-survie -- du -sh /data/  # Espace utilisé

# === DEBUG ===
k -n mineshark get events --sort-by='.lastTimestamp' | tail -20
k -n mineshark describe pod <NOM>          # Section "Events" en bas
```

---

## 19. Setup Local (WSL2) — Dev sans VPS

Tu peux tout tester en local sans payer de VPS et sans ouvrir de ports.

### 19.1 Installer K3s sur WSL2

```bash
# Installe K3s
make local-install-k3s
# ou manuellement :
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifie
kubectl get nodes
```

### 19.2 Déployer en local

```bash
cd ~/mineshark   # ton repo cloné

make setup        # Crée namespace + secrets
make deploy-all   # Déploie tout

make status       # Vérifie que tout tourne
```

### 19.3 Se connecter en local

Les serveurs sont accessibles sur `localhost:25565` (Java) et `localhost:19132` (Bedrock) via les NodePorts.

---

## 20. FAQ & Concepts Expliqués

### Pourquoi l'image s'appelle `itzg/bungeecord` pour Velocity ?

L'auteur (itzg) a créé l'image pour BungeeCord d'abord, puis a ajouté le support Velocity via la variable `TYPE=VELOCITY`. Le nom est resté par compatibilité. Le résultat est bien Velocity qui tourne.

### online-mode true ou false ?

`online-mode=true` est sur **Velocity uniquement**. Il vérifie les comptes Mojang (Java) et via Floodgate les comptes Xbox (Bedrock). Les serveurs backend ont `online-mode=false` car Velocity a déjà fait la vérification — ils lui font confiance via le forwarding secret.

Résultat : les joueurs Java payés et Bedrock (compte Xbox gratuit) peuvent se connecter. Les cracks Java sont bloqués.

Si tu veux accepter les cracks, mets `online-mode=false` sur Velocity et ajoute un plugin AuthMe (login/register en jeu) + une base SQLite ou MariaDB. Mais c'est un risque de sécurité (usurpation de pseudo).

### Les serveurs backend ne sont pas en `expose` ?

Oui, exactement ! Les services backend sont en `ClusterIP` (équivalent de `expose:` dans Docker Compose) — accessibles uniquement à l'intérieur du cluster. Seul Velocity a un `NodePort` (équivalent de `ports:`) qui est exposé à l'extérieur. Si tu ajoutes Nginx/Traefik pour le site web, il aura aussi un port externe (443), mais les services internes (Next.js, NestJS, PostgreSQL) seront en ClusterIP.

### ConfigMap vs fichier de config — c'est le même contenu ?

Oui. Tu écris le contenu (velocity.toml) dans un ConfigMap YAML → K8s le monte comme fichier dans le conteneur → Velocity le lit comme un fichier normal. Deux représentations du même contenu. L'avantage du ConfigMap : versionné dans Git, déployable via CI/CD, pas besoin de se connecter au serveur pour modifier.

### Le forwarding secret — c'est juste un env global ?

Oui, c'est un Secret K8s (chiffré) que tous les services lisent. L'avantage vs un `.env` : chiffré, jamais en clair dans Git, modifiable sans rebuild d'image.

### Passer de modé à vanilla sans quitter Minecraft ?

Oui ! `/server lobby`, `/server survie`, ou clic sur un NPC. Velocity gère le transfert. Mais le client doit avoir les mods installés pour aller sur le serveur modé. Un client vanilla sera kick du serveur modé avec un message d'erreur. Un client modé peut aller partout (modé + vanilla).

### Créer un launcher custom ?

C'est faisable avec **SKCraft Launcher** (open source). Le joueur télécharge "Mineshark Launcher", clique "Jouer", et le launcher installe les mods + connecte au serveur automatiquement. Bon projet Phase 3, Java uniquement (Bedrock utilise l'app officielle + GeyserMC).

---

## 21. Roadmap & Phases

### Phase 1 — Infrastructure de base
- [ ] Commander VPS (Contabo ou Netcup)
- [ ] Setup Debian 12 + sécurisation
- [ ] Installer K3s
- [ ] Déployer Velocity + GeyserMC + Floodgate + TCPShield
- [ ] Déployer Lobby (Paper)
- [ ] Déployer Serveur Jeux (Paper)
- [ ] Déployer Survie Modée (NeoForge + Modded Together)
- [ ] Déployer Dev/Sandbox (Paper)
- [ ] CI/CD GitHub Actions
- [ ] Backups automatiques
- [ ] DNS + domaine mineshark.fr

### Phase 2 — Plugins & Gameplay
- [ ] Plugins lobby (portails, NPC : Citizens + CommandNPC)
- [ ] Plugins essentiels (EssentialsX, LuckPerms, WorldGuard)
- [ ] Minijeux sur le serveur jeux
- [ ] Tester Hydraulic (crossplay modé Bedrock)
- [ ] Sandbox modée pour tester des mods

### Phase 3 — Site Web & CMS
- [ ] CMS Minecraft custom (Next.js + NestJS + PostgreSQL)
- [ ] Auth (lien compte Minecraft ↔ compte site)
- [ ] Dashboard joueurs (stats, classements)
- [ ] Panel admin (RCON web, gestion serveurs via API K8s)
- [ ] Monitoring avancé (Prometheus + Grafana)

### Phase 4 — Launcher & Automatisation
- [ ] Launcher custom Mineshark (SKCraft Launcher)
- [ ] Alertes Discord (serveur down, backup fail)
- [ ] Auto-scaling dev serveurs
- [ ] Bot Discord

### Phase 5 — Hytale (quand disponible)
- [ ] Serveur Hytale dans le même cluster K3s
- [ ] Intégration dans le CMS
- [ ] Cross-lobby Minecraft/Hytale

---

## Sources & Références

### Logiciel serveur
- [PaperMC](https://papermc.io/) — serveur Paper
- [PurpurMC](https://purpurmc.org/) — fork de Paper avec plus de customisation
- [Velocity](https://papermc.io/software/velocity/) — proxy Minecraft moderne
- [Velocity — Pourquoi Velocity](https://docs.papermc.io/velocity/why-velocity/)

### Crossplay
- [GeyserMC](https://geysermc.org/) — crossplay Java/Bedrock
- [GeyserMC Hydraulic](https://github.com/GeyserMC/Hydraulic) — crossplay modé (beta)

### Docker & K8s
- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) — image Docker MC
- [itzg Docker MC Docs](https://docker-minecraft-server.readthedocs.io/) — documentation complète
- [K3s Documentation](https://docs.k3s.io/) — K3s officiel
- [Traefik](https://traefik.io/) — ingress controller inclus dans K3s

### VPS
- [Contabo](https://contabo.com/) — VPS budget
- [Netcup](https://www.netcup.com/) — VPS CPU dédié
- [Hetzner Cloud](https://www.hetzner.com/cloud/) — VPS performant (plus cher depuis avril 2026)

### Sécurité
- [TCPShield](https://tcpshield.com/) — protection DDoS Minecraft gratuite
- [Hetzner DNS](https://www.hetzner.com/dns/) — DNS gratuit

### Modpack
- [Modded Together — CurseForge](https://www.curseforge.com/minecraft/modpacks/moddedtogether)

### Launcher
- [SKCraft Launcher](https://github.com/SKCraft/Launcher) — launcher custom open source
- [Prism Launcher](https://prismlauncher.org/) — launcher open source
