# Guide Mineshark — Infrastructure Minecraft Complète

> Guide détaillé pour monter un réseau Minecraft (modé + vanilla + dev) avec K3s, Docker, CI/CD, et crossplay Java/Bedrock.

---

## Table des matières

1. [Architecture Globale](#1-architecture-globale)
2. [Choix du VPS](#2-choix-du-vps)
3. [Setup Initial du VPS](#3-setup-initial-du-vps)
4. [Apprendre Docker — Les Bases](#4-apprendre-docker--les-bases)
5. [Installer K3s](#5-installer-k3s)
6. [Comprendre K3s / Kubernetes](#6-comprendre-k3s--kubernetes)
7. [Velocity — Le Proxy](#7-velocity--le-proxy)
8. [Serveur Vanilla/Plugins (Paper)](#8-serveur-vanillaplugins-paper)
9. [Serveur Modé (NeoForge — Modded Together)](#9-serveur-modé-neoforge--modded-together)
10. [Crossplay Java + Bedrock (GeyserMC)](#10-crossplay-java--bedrock-geysermc)
11. [Serveur Dev/Sandbox](#11-serveur-devsandbox)
12. [Structure du Repo GitHub](#12-structure-du-repo-github)
13. [CI/CD avec GitHub Actions](#13-cicd-avec-github-actions)
14. [Monitoring & Backups](#14-monitoring--backups)
15. [Commandes Utiles K3s](#15-commandes-utiles-k3s)
16. [Roadmap & Next Steps](#16-roadmap--next-steps)

---

## 1. Architecture Globale

### Schéma du réseau

```
Internet (Joueurs)
       │
       │  TCP :25565 (Java)
       │  UDP :19132 (Bedrock)
       │
┌──────▼──────────────────────────────────┐
│           VPS (Hetzner CX32+)           │
│              K3s Cluster                │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         Velocity Proxy            │  │
│  │   + GeyserMC (plugin Velocity)    │  │
│  │   + Floodgate                     │  │
│  │   Ports: 25565/TCP, 19132/UDP     │  │
│  └──────┬────────┬────────┬──────────┘  │
│         │        │        │             │
│    ┌────▼───┐┌───▼────┐┌──▼─────┐      │
│    │ lobby  ││ survie ││  dev   │      │
│    │ Paper  ││NeoForge││ Paper  │      │
│    │ :25566 ││ :25567 ││ :25568 │      │
│    │plugins ││ modé   ││sandbox │      │
│    │minijeux││Together││ test   │      │
│    └────────┘└────────┘└────────┘      │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Volumes Persistants (PVC)        │  │
│  │  /data/lobby, /data/survie,       │  │
│  │  /data/dev, /data/backups         │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Explication des composants

- **Velocity** : Le proxy moderne de PaperMC. C'est le point d'entrée unique. Les joueurs se connectent dessus et il les route vers les bons serveurs. C'est lui le "petit serveur proxy" dont tu te souvenais.
- **Lobby/Vanilla (Paper)** : Serveur Paper pour les plugins, maps custom, minijeux. C'est aussi le serveur par défaut quand un joueur se connecte.
- **Survie Modé (NeoForge)** : Le serveur avec le modpack "Modded Together" pour jouer en survie avec ta pote.
- **Dev/Sandbox (Paper)** : Ton terrain de jeu pour dev des plugins, tester des configs. Tu peux le restart/casser sans affecter les autres.
- **GeyserMC** : Plugin installé sur Velocity qui traduit les connexions Bedrock en Java. Permet aux joueurs sur téléphone, console, Windows 10 de rejoindre.
- **Floodgate** : Complément de Geyser qui permet aux joueurs Bedrock de rejoindre sans compte Java.
- **K3s** : Version légère de Kubernetes. Gère tous les conteneurs, les redémarrages automatiques, le réseau interne.

### Pourquoi cette architecture ?

- **Isolation** : Chaque serveur est dans son propre Pod K3s. Si le serveur dev crash, la survie continue.
- **Scalabilité** : Tu peux ajouter un serveur en ajoutant un fichier YAML.
- **Apprentissage** : Tu apprends K8s sur un vrai projet, pas un tuto hello-world.
- **CI/CD** : Push sur GitHub → tes configs se déploient automatiquement.
- **Point d'entrée unique** : Une seule IP, un seul port. Les joueurs tapent `play.mineshark.fr` et Velocity fait le reste.

---

## 2. Choix du VPS

### Recommandation : Hetzner Cloud

Après recherche, **Hetzner** est le meilleur rapport qualité/prix en Europe pour ce type de projet.

#### Pourquoi pas Vultr ?

Tu mentionnais Vultr et le fait qu'ils ne facturent pas quand le serveur est éteint. **C'est faux malheureusement** — Vultr facture les instances même quand elles sont stoppées car les ressources (CPU, RAM, IP, stockage) restent réservées. Il faut DÉTRUIRE l'instance pour arrêter la facturation, ce qui veut dire perdre tes données.

#### Plans Hetzner recommandés

| Plan | vCPU | RAM | SSD | Prix/mois | Utilisation |
|------|------|-----|-----|-----------|-------------|
| **CX32** | 4 vCPU | 8 GB | 80 GB | ~8€ | Minimum viable (serré) |
| **CX42** | 8 vCPU | 16 GB | 160 GB | ~16€ | **Recommandé** — confortable |
| **CCX23** | 4 vCPU dédiés | 16 GB | 80 GB | ~18€ | Si besoin de perf constante |

**Ma recommandation** : Le **CX42 à ~16€/mois**. Avec 16 GB de RAM et 8 vCPU, tu peux faire tourner :
- Velocity : ~512 MB RAM
- Lobby Paper : ~1-2 GB RAM
- Survie NeoForge : ~4-6 GB RAM (les modpacks sont gourmands)
- Dev Paper : ~1-2 GB RAM
- K3s overhead : ~512 MB RAM
- Système : ~1 GB RAM

Total : ~9-12 GB sur 16 GB disponibles. Tu as de la marge.

#### Datacenter

Choisis **Falkenstein (fsn1)** ou **Nuremberg (nbg1)** en Allemagne — les plus proches de la France avec les meilleures perfs réseau.

#### Alternatives si budget plus serré

| Provider | Plan | RAM | Prix | Notes |
|----------|------|-----|------|-------|
| OVH | VPS Essential | 8 GB | ~10€ | Bien mais interface moins moderne |
| Contabo | VPS M | 16 GB | ~12€ | Beaucoup de RAM pour le prix, perf CPU moyenne |

---

## 3. Setup Initial du VPS

### 3.1 Créer le VPS sur Hetzner

1. Va sur https://www.hetzner.com/cloud
2. Crée un compte
3. Nouveau projet → "mineshark"
4. Nouveau serveur :
   - Location : **Falkenstein**
   - Image : **Ubuntu 24.04**
   - Type : **CX42** (ou CX32 si budget serré)
   - Networking : IPv4 + IPv6
   - SSH Key : Ajoute ta clé publique SSH (on va la générer si besoin)

### 3.2 Générer une clé SSH (si pas déjà fait)

Sur ta machine locale :

```bash
# Génère une paire de clés SSH
ssh-keygen -t ed25519 -C "alexis@mineshark"

# Affiche ta clé publique (à copier dans Hetzner)
cat ~/.ssh/id_ed25519.pub
```

### 3.3 Première connexion

```bash
# Remplace X.X.X.X par l'IP de ton VPS
ssh root@X.X.X.X
```

### 3.4 Sécurisation de base

```bash
# Met à jour le système
apt update && apt upgrade -y

# Crée un utilisateur non-root
adduser mineshark
usermod -aG sudo mineshark

# Copie la clé SSH pour le nouvel utilisateur
mkdir -p /home/mineshark/.ssh
cp /root/.ssh/authorized_keys /home/mineshark/.ssh/
chown -R mineshark:mineshark /home/mineshark/.ssh
chmod 700 /home/mineshark/.ssh
chmod 600 /home/mineshark/.ssh/authorized_keys

# Désactive la connexion root SSH
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Configure le firewall
ufw allow OpenSSH
ufw allow 25565/tcp    # Minecraft Java
ufw allow 19132/udp    # Minecraft Bedrock (GeyserMC)
ufw allow 6443/tcp     # K3s API (pour kubectl distant)
ufw enable

# Installe les outils de base
apt install -y curl wget git htop nano unzip
```

### 3.5 Reconnecte-toi avec le nouvel utilisateur

```bash
# Déconnecte-toi
exit

# Reconnecte-toi avec mineshark
ssh mineshark@X.X.X.X
```

---

## 4. Apprendre Docker — Les Bases

Avant K3s, faut comprendre Docker car K3s utilise containerd (le moteur de conteneurs sous Docker).

### 4.1 Installer Docker

```bash
# Installation officielle Docker
curl -fsSL https://get.docker.com | sh

# Ajoute ton user au groupe docker (pas besoin de sudo pour docker)
sudo usermod -aG docker mineshark

# Déconnecte/reconnecte pour appliquer le groupe
exit
# Re-SSH...

# Vérifie que ça marche
docker --version
docker run hello-world
```

### 4.2 Concepts clés Docker

**Image** = Un modèle en lecture seule. Comme un snapshot de système. Ex: `itzg/minecraft-server` est une image qui contient tout pour faire tourner un serveur Minecraft.

**Conteneur** = Une instance en cours d'exécution d'une image. C'est ton serveur Minecraft qui tourne.

**Volume** = Stockage persistant. Les données du serveur (monde, configs) survivent même si tu supprimes le conteneur.

**Dockerfile** = La recette pour construire une image.

**docker-compose.yml** = Un fichier qui décrit plusieurs conteneurs et comment ils communiquent.

### 4.3 Test rapide — Lancer un serveur Minecraft avec Docker

C'est juste pour comprendre, on va pas garder ça. L'objectif c'est de tester l'image `itzg/minecraft-server`.

```bash
# Crée un dossier de test
mkdir -p ~/docker-test && cd ~/docker-test

# Lance un serveur Minecraft Paper rapide
docker run -d \
  --name mc-test \
  -p 25565:25565 \
  -e EULA=TRUE \
  -e TYPE=PAPER \
  -e VERSION=1.21.4 \
  -e MEMORY=1G \
  -v mc-test-data:/data \
  itzg/minecraft-server

# Vérifie que ça tourne
docker ps

# Regarde les logs (Ctrl+C pour quitter)
docker logs -f mc-test

# Quand tu as fini de tester, supprime tout
docker stop mc-test
docker rm mc-test
docker volume rm mc-test-data
```

**Ce qui se passe** :
- `-d` : lance en arrière-plan (detached)
- `-p 25565:25565` : mappe le port 25565 du conteneur vers le VPS
- `-e EULA=TRUE` : accepte l'EULA Minecraft
- `-e TYPE=PAPER` : utilise le logiciel serveur Paper
- `-v mc-test-data:/data` : stocke les données du monde dans un volume nommé

### 4.4 Docker Compose — Plusieurs conteneurs

Crée le fichier `~/docker-test/docker-compose.yml` :

```yaml
# docker-compose.yml — Juste pour comprendre le concept
# On n'utilisera PAS docker-compose en production, on utilisera K3s

services:
  velocity:
    image: itzg/bungeecord
    environment:
      TYPE: VELOCITY
      MEMORY: 512m
    ports:
      - "25565:25577"
    volumes:
      - velocity-data:/server

  lobby:
    image: itzg/minecraft-server
    environment:
      EULA: "TRUE"
      TYPE: PAPER
      VERSION: "1.21.1"
      MEMORY: 1G
      ONLINE_MODE: "FALSE"  # Velocity gère l'auth
    volumes:
      - lobby-data:/data
    # Pas de ports exposés — seul Velocity est exposé

volumes:
  velocity-data:
  lobby-data:
```

```bash
# Lance les deux conteneurs
docker compose up -d

# Vérifie
docker compose ps

# Arrête tout
docker compose down
```

**Comprends bien** : Docker Compose c'est bien pour du dev local ou des petits projets. Mais pour ton projet avec plusieurs serveurs, du scaling, des restarts automatiques, et du CI/CD, K3s est largement supérieur. Docker Compose n'a pas :
- De health checks avancés avec restart automatique
- De rolling updates (mise à jour sans downtime)
- De gestion déclarative du réseau interne
- D'intégration CI/CD native

---

## 5. Installer K3s

### 5.1 Pourquoi K3s et pas K8s complet ?

**K3s** est Kubernetes, mais en version light (~60 MB au lieu de ~300 MB). Il est conçu pour :
- Les VPS avec peu de ressources
- L'IoT / edge computing
- L'apprentissage
- La production sur des serveurs uniques (exactement ton cas)

Il supporte 100% des manifests Kubernetes standard. Tout ce que tu apprends sur K3s est directement transposable à K8s.

### 5.2 Installation

```bash
# Installe K3s
curl -sfL https://get.k3s.io | sh -

# Vérifie que K3s tourne
sudo systemctl status k3s

# Vérifie que le cluster est up
sudo kubectl get nodes
# Tu devrais voir ton nœud en "Ready"
```

### 5.3 Configurer kubectl pour ton utilisateur

```bash
# Copie la config K3s pour ton user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Optionnel : alias pratique
echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

# Test
kubectl get nodes
k get nodes   # même chose avec l'alias
```

### 5.4 Accéder à kubectl depuis ta machine locale (optionnel mais recommandé)

Sur ta **machine locale** :

```bash
# Installe kubectl si pas déjà fait
# macOS
brew install kubectl
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Copie le kubeconfig depuis le VPS
scp mineshark@X.X.X.X:~/.kube/config ~/.kube/config-mineshark

# Edite le fichier pour changer l'adresse
# Remplace 127.0.0.1 par l'IP publique de ton VPS
sed -i 's/127.0.0.1/X.X.X.X/' ~/.kube/config-mineshark

# Utilise ce config
export KUBECONFIG=~/.kube/config-mineshark
kubectl get nodes
```

---

## 6. Comprendre K3s / Kubernetes

### Concepts essentiels

Avant de déployer quoi que ce soit, voici les concepts K8s que tu vas utiliser :

**Namespace** = Un espace isolé dans le cluster. On va créer un namespace `mineshark` pour séparer nos ressources des trucs système.

**Pod** = La plus petite unité dans K8s. Un Pod contient un ou plusieurs conteneurs. En général, 1 Pod = 1 conteneur = 1 serveur Minecraft.

**Deployment** = Décrit combien de Pods tu veux et comment les créer. Gère les updates et les rollbacks.

**Service** = Expose un Pod sur le réseau interne du cluster avec un nom DNS stable. Quand tu veux que Velocity parle au serveur lobby, il utilise le Service.

**PersistentVolumeClaim (PVC)** = Demande de stockage persistant. Le monde Minecraft et les configs sont stockés dans un PVC pour survivre aux redémarrages.

**ConfigMap** = Stocke de la configuration (ex: velocity.toml) sous forme de clé-valeur dans K8s.

**Secret** = Comme ConfigMap mais pour des données sensibles (mots de passe RCON, tokens).

### Analogie simple

Pense à K8s comme un chef de chantier :
- Tu lui donnes des **plans** (fichiers YAML)
- Il s'assure que la **construction** (conteneurs) correspond aux plans
- Si un ouvrier (Pod) tombe malade, il le **remplace automatiquement**
- Tu peux modifier les plans et il **adapte** le chantier sans tout démolir

---

## 7. Velocity — Le Proxy

### 7.1 Créer la structure de fichiers

Sur ton VPS :

```bash
# Structure du projet
mkdir -p ~/mineshark/k8s/{base,velocity,lobby,survie,dev}
mkdir -p ~/mineshark/configs/{velocity,lobby,survie,dev}
```

### 7.2 Namespace

Crée le fichier `~/mineshark/k8s/base/namespace.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mineshark
  labels:
    app: mineshark
```

```bash
# Applique le namespace
kubectl apply -f ~/mineshark/k8s/base/namespace.yaml

# Vérifie
kubectl get namespaces
```

### 7.3 Configuration Velocity

Crée le fichier `~/mineshark/configs/velocity/velocity.toml` :

```toml
# velocity.toml — Configuration principale de Velocity
# Docs: https://docs.papermc.io/velocity/configuration

# L'adresse sur laquelle Velocity écoute
bind = "0.0.0.0:25577"

# Mode online pour la sécurité (Velocity vérifie les comptes Mojang)
online-mode = true

# Le serveur par défaut quand un joueur se connecte
[servers]
  lobby = "mc-lobby:25565"
  survie = "mc-survie:25565"
  dev = "mc-dev:25565"
  
  # L'ordre dans lequel Velocity essaie de connecter les joueurs
  try = ["lobby"]

[forced-hosts]
  # Si tu as un domaine plus tard :
  # "lobby.mineshark.fr" = ["lobby"]
  # "survie.mineshark.fr" = ["survie"]

[advanced]
  # Compression réseau — laisse les défauts, c'est déjà optimisé
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

### 7.4 ConfigMap Velocity

Crée `~/mineshark/k8s/velocity/configmap.yaml` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: velocity-config
  namespace: mineshark
data:
  velocity.toml: |
    bind = "0.0.0.0:25577"
    online-mode = true

    [servers]
      lobby = "mc-lobby:25565"
      survie = "mc-survie:25565"
      dev = "mc-dev:25565"
      try = ["lobby"]

    [forced-hosts]

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

### 7.5 Forwarding Secret

Velocity utilise un "forwarding secret" pour sécuriser la communication avec les serveurs backend. Tous les serveurs doivent partager ce secret.

```bash
# Génère un secret aléatoire
FORWARDING_SECRET=$(openssl rand -hex 16)
echo "Ton forwarding secret : $FORWARDING_SECRET"
echo "GARDE-LE PRÉCIEUSEMENT !"

# Crée le Secret K8s
kubectl create secret generic velocity-forwarding-secret \
  --namespace=mineshark \
  --from-literal=forwarding-secret="$FORWARDING_SECRET"
```

### 7.6 Deployment Velocity

Crée `~/mineshark/k8s/velocity/deployment.yaml` :

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
      containers:
        - name: velocity
          image: itzg/bungeecord:latest
          env:
            - name: TYPE
              value: "VELOCITY"
            - name: MEMORY
              value: "512m"
            # On montera la config et les plugins via volumes
          ports:
            - containerPort: 25577
              name: minecraft
              protocol: TCP
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "768Mi"
              cpu: "500m"
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
            claimName: velocity-pvc
```

### 7.7 PVC Velocity

Crée `~/mineshark/k8s/velocity/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: velocity-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # K3s utilise local-path par défaut, pas besoin de storageClassName
```

### 7.8 Service Velocity

Crée `~/mineshark/k8s/velocity/service.yaml` :

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
      nodePort: 25565    # Port externe accessible par les joueurs
      protocol: TCP
    - name: minecraft-bedrock
      port: 19132
      targetPort: 19132
      nodePort: 19132
      protocol: UDP
```

### 7.9 Déployer Velocity

```bash
# Applique tous les fichiers Velocity
kubectl apply -f ~/mineshark/k8s/velocity/

# Vérifie le déploiement
kubectl -n mineshark get pods
kubectl -n mineshark get services
kubectl -n mineshark logs -f deployment/velocity
```

---

## 8. Serveur Vanilla/Plugins (Paper)

C'est le serveur lobby — celui où les joueurs arrivent en premier. Paper pour les plugins et les minijeux.

### 8.1 PVC Lobby

Crée `~/mineshark/k8s/lobby/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lobby-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 8.2 Deployment Lobby

Crée `~/mineshark/k8s/lobby/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-lobby
  namespace: mineshark
  labels:
    app: mc-lobby
    component: server
    type: paper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mc-lobby
  strategy:
    type: Recreate   # Important : un seul serveur MC à la fois par monde
  template:
    metadata:
      labels:
        app: mc-lobby
        component: server
        type: paper
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
            
            # Mode online FALSE car Velocity gère l'authentification
            - name: ONLINE_MODE
              value: "FALSE"
            
            # Config Velocity forwarding
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            
            # Paramètres serveur
            - name: MOTD
              value: "§b§lMineshark §7- §eLobby"
            - name: MAX_PLAYERS
              value: "50"
            - name: DIFFICULTY
              value: "normal"
            - name: SPAWN_PROTECTION
              value: "0"
            - name: VIEW_DISTANCE
              value: "10"
            - name: SIMULATION_DISTANCE
              value: "8"
            
            # RCON pour l'admin à distance
            - name: ENABLE_RCON
              value: "TRUE"
            - name: RCON_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: rcon-secret
                  key: rcon-password
            
          ports:
            - containerPort: 25565
              name: minecraft
            - containerPort: 25575
              name: rcon
          
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
            limits:
              memory: "2560Mi"
              cpu: "2000m"
          
          readinessProbe:
            exec:
              command:
                - mc-health
            initialDelaySeconds: 60
            periodSeconds: 10
          livenessProbe:
            exec:
              command:
                - mc-health
            initialDelaySeconds: 120
            periodSeconds: 30
          
          volumeMounts:
            - name: data
              mountPath: /data
      
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: lobby-pvc
```

### 8.3 Service Lobby

Crée `~/mineshark/k8s/lobby/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-lobby
  namespace: mineshark
  labels:
    app: mc-lobby
spec:
  type: ClusterIP    # Accessible uniquement depuis le cluster (via Velocity)
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

### 8.4 Créer le Secret RCON

```bash
# Génère un mot de passe RCON
RCON_PASS=$(openssl rand -base64 16)
echo "RCON password : $RCON_PASS"

kubectl create secret generic rcon-secret \
  --namespace=mineshark \
  --from-literal=rcon-password="$RCON_PASS"
```

### 8.5 Configuration Paper pour Velocity

Après le premier démarrage du serveur, tu dois configurer Paper pour accepter le forwarding Velocity.

```bash
# Attends que le pod soit prêt
kubectl -n mineshark wait --for=condition=ready pod -l app=mc-lobby --timeout=120s

# Edite la config Paper pour activer Velocity forwarding
kubectl -n mineshark exec -it deployment/mc-lobby -- bash

# Dans le conteneur :
# 1. Édite config/paper-global.yml
cat > /data/config/paper-global.yml << 'EOF'
proxies:
  velocity:
    enabled: true
    online-mode: true
    secret: ""   # Le secret est injecté via la variable d'env PAPER_VELOCITY_SECRET
EOF

# 2. Quitte le conteneur
exit

# 3. Redémarre le pod pour appliquer
kubectl -n mineshark rollout restart deployment/mc-lobby
```

**Note importante** : L'image `itzg/minecraft-server` gère automatiquement la config Velocity si tu définis `PAPER_VELOCITY_SECRET`. Tu n'as normalement pas besoin de l'éditer manuellement. Mais si ça marche pas, c'est la méthode manuelle.

### 8.6 Déployer le Lobby

```bash
kubectl apply -f ~/mineshark/k8s/lobby/

# Vérifie
kubectl -n mineshark get pods
kubectl -n mineshark logs -f deployment/mc-lobby
```

---

## 9. Serveur Modé (NeoForge — Modded Together)

Le plus complexe car il faut installer le modpack CurseForge automatiquement.

### 9.1 PVC Survie

Crée `~/mineshark/k8s/survie/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: survie-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi     # Les modpacks prennent plus de place
```

### 9.2 Secret pour CurseForge API

Pour télécharger automatiquement un modpack CurseForge, il faut une API key.

1. Va sur https://console.curseforge.com/
2. Crée un compte / connecte-toi
3. Génère une API key

```bash
# Crée le secret avec ta clé API CurseForge
kubectl create secret generic curseforge-api-key \
  --namespace=mineshark \
  --from-literal=api-key="TON_API_KEY_ICI"
```

### 9.3 Deployment Survie

Crée `~/mineshark/k8s/survie/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-survie
  namespace: mineshark
  labels:
    app: mc-survie
    component: server
    type: neoforge
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
        type: neoforge
    spec:
      containers:
        - name: minecraft
          image: itzg/minecraft-server:latest
          env:
            - name: EULA
              value: "TRUE"
            
            # --- Modpack CurseForge ---
            # L'image itzg supporte le téléchargement auto de modpacks CF
            - name: MOD_PLATFORM
              value: "AUTO_CURSEFORGE"
            - name: CF_SLUG
              value: "moddedtogether"
            # Ou utilise l'ID du projet :
            # - name: CF_PAGE_URL
            #   value: "https://www.curseforge.com/minecraft/modpacks/moddedtogether"
            - name: CF_API_KEY
              valueFrom:
                secretKeyRef:
                  name: curseforge-api-key
                  key: api-key
            
            # --- Performance ---
            - name: MEMORY
              value: "5G"
            - name: JVM_XX_OPTS
              value: "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"
            
            # --- Velocity ---
            - name: ONLINE_MODE
              value: "FALSE"
            
            # --- Serveur ---
            - name: MOTD
              value: "§b§lMineshark §7- §cSurvie Modée"
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
              name: minecraft
            - containerPort: 25575
              name: rcon
          
          resources:
            requests:
              memory: "5Gi"
              cpu: "1000m"
            limits:
              memory: "6Gi"
              cpu: "4000m"
          
          # Délai plus long pour les modpacks (téléchargement + installation)
          readinessProbe:
            exec:
              command:
                - mc-health
            initialDelaySeconds: 180
            periodSeconds: 15
          livenessProbe:
            exec:
              command:
                - mc-health
            initialDelaySeconds: 300
            periodSeconds: 30
            failureThreshold: 5
          
          volumeMounts:
            - name: data
              mountPath: /data
      
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: survie-pvc
```

### 9.4 Service Survie

Crée `~/mineshark/k8s/survie/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-survie
  namespace: mineshark
  labels:
    app: mc-survie
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

### 9.5 Déployer la Survie

```bash
kubectl apply -f ~/mineshark/k8s/survie/

# Le premier démarrage sera LONG (téléchargement du modpack)
# Surveille les logs
kubectl -n mineshark logs -f deployment/mc-survie
```

### 9.6 Note sur le crossplay modé

**Important** : Le serveur modé NeoForge ne sera **PAS** accessible aux joueurs Bedrock via GeyserMC. GeyserMC traduit les paquets Java vanilla ↔ Bedrock, mais il ne peut pas gérer les mods custom. Les joueurs Bedrock pourront rejoindre le lobby et le serveur dev (vanilla/plugins), mais pas la survie modée. C'est une limitation technique de GeyserMC.

---

## 10. Crossplay Java + Bedrock (GeyserMC)

### 10.1 Comment ça marche

GeyserMC s'installe comme **plugin sur Velocity**. Il écoute sur le port UDP 19132 (Bedrock) et traduit les connexions en protocole Java avant de les envoyer aux serveurs backend.

**Floodgate** permet aux joueurs Bedrock de se connecter sans compte Java. Leur pseudo sera préfixé par un `.` (ex: `.MommyShark`).

### 10.2 Installation sur Velocity

On va utiliser un **init container** qui télécharge les plugins avant le démarrage de Velocity.

Modifie `~/mineshark/k8s/velocity/deployment.yaml` pour ajouter les plugins :

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
              
              # Crée le dossier plugins
              mkdir -p /server/plugins
              
              # Télécharge GeyserMC pour Velocity
              wget -O /server/plugins/Geyser-Velocity.jar \
                "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity"
              
              # Télécharge Floodgate pour Velocity
              wget -O /server/plugins/Floodgate-Velocity.jar \
                "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity"
              
              echo "=== Plugins downloaded ==="
              ls -la /server/plugins/
          volumeMounts:
            - name: velocity-data
              mountPath: /server

      containers:
        - name: velocity
          image: itzg/bungeecord:latest
          env:
            - name: TYPE
              value: "VELOCITY"
            - name: MEMORY
              value: "512m"
          ports:
            - containerPort: 25577
              name: minecraft-java
              protocol: TCP
            - containerPort: 19132
              name: minecraft-bedrock
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
            claimName: velocity-pvc
```

### 10.3 Configuration GeyserMC

Après le premier démarrage, GeyserMC génère sa config. Tu peux la modifier :

```bash
# Entre dans le pod Velocity
kubectl -n mineshark exec -it deployment/velocity -- sh

# Édite la config Geyser
cat /server/plugins/Geyser-Velocity/config.yml
```

Les paramètres importants à vérifier dans `config.yml` :

```yaml
bedrock:
  address: 0.0.0.0
  port: 19132
  motd1: "Mineshark"
  motd2: "Java + Bedrock"

remote:
  address: auto
  port: 25577
  auth-type: floodgate  # Utilise Floodgate pour l'auth Bedrock
```

### 10.4 Floodgate sur les serveurs backend

Floodgate doit aussi être installé sur chaque serveur Paper backend pour que les skins et données Bedrock fonctionnent correctement.

Pour le lobby, modifie le deployment pour ajouter Floodgate :

Ajoute cette variable d'environnement dans le deployment du lobby :

```yaml
            # Ajout dans les env du conteneur mc-lobby
            - name: PLUGINS
              value: "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
```

L'image `itzg/minecraft-server` téléchargera automatiquement le plugin au démarrage.

### 10.5 Connexion Bedrock

Les joueurs Bedrock se connectent avec :
- **Adresse** : L'IP de ton VPS (ou ton domaine)
- **Port** : 19132

---

## 11. Serveur Dev/Sandbox

Le serveur que tu peux casser, restart, modifier sans affecter les joueurs sur le lobby ou la survie.

### 11.1 PVC Dev

Crée `~/mineshark/k8s/dev/pvc.yaml` :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dev-pvc
  namespace: mineshark
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 11.2 Deployment Dev

Crée `~/mineshark/k8s/dev/deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-dev
  namespace: mineshark
  labels:
    app: mc-dev
    component: server
    type: paper
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
        type: paper
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
              value: "2G"
            - name: ONLINE_MODE
              value: "FALSE"
            - name: PAPER_VELOCITY_SECRET
              valueFrom:
                secretKeyRef:
                  name: velocity-forwarding-secret
                  key: forwarding-secret
            - name: MOTD
              value: "§b§lMineshark §7- §aDev/Sandbox §c§l[UNSTABLE]"
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
            # Auto-download Floodgate pour crossplay Bedrock
            - name: PLUGINS
              value: "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
          ports:
            - containerPort: 25565
              name: minecraft
            - containerPort: 25575
              name: rcon
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
            limits:
              memory: "2560Mi"
              cpu: "2000m"
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: dev-pvc
```

### 11.3 Service Dev

Crée `~/mineshark/k8s/dev/service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mc-dev
  namespace: mineshark
  labels:
    app: mc-dev
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

### 11.4 Déployer le Dev

```bash
kubectl apply -f ~/mineshark/k8s/dev/

# Le serveur dev est en Creative par défaut
# Tu peux le restart sans affecter les autres :
kubectl -n mineshark rollout restart deployment/mc-dev
```

### 11.5 Scale down le Dev quand pas utilisé

Pour économiser des ressources :

```bash
# Éteindre le serveur dev
kubectl -n mineshark scale deployment/mc-dev --replicas=0

# Le rallumer
kubectl -n mineshark scale deployment/mc-dev --replicas=1
```

---

## 12. Structure du Repo GitHub

### 12.1 Structure recommandée

```
mineshark/
├── .github/
│   └── workflows/
│       ├── deploy.yml          # CI/CD principal
│       ├── backup.yml          # Backup automatique
│       └── lint.yml            # Validation des YAML
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
│   ├── survie/
│   │   ├── deployment.yaml
│   │   ├── pvc.yaml
│   │   └── service.yaml
│   └── dev/
│       ├── deployment.yaml
│       ├── pvc.yaml
│       └── service.yaml
├── configs/
│   ├── velocity/
│   │   └── velocity.toml
│   ├── lobby/
│   │   └── paper-global.yml
│   └── survie/
│       └── server.properties
├── plugins/
│   └── README.md               # Liste des plugins utilisés
├── scripts/
│   ├── setup-vps.sh            # Script d'installation initial
│   ├── backup.sh               # Script de backup
│   └── restore.sh              # Script de restauration
├── docs/
│   ├── ARCHITECTURE.md         # Ce qu'on a décrit plus haut
│   ├── COMMANDS.md             # Commandes utiles
│   └── TROUBLESHOOTING.md     # Problèmes courants
├── .gitignore
└── README.md
```

### 12.2 .gitignore

Crée `~/mineshark/.gitignore` :

```gitignore
# Secrets — JAMAIS dans Git
*.secret
*.key
kubeconfig*

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
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
docker-compose.override.yml

# Node (pour le site plus tard)
node_modules/
.next/
.env
.env.local
```

### 12.3 Initialiser le repo

```bash
cd ~/mineshark

# Copie la structure vers le repo
# (tu as déjà un repo git dans /sessions/gracious-dreamy-euler/mnt/mineshark)
# Recrée la même structure dans ton repo

git add .
git commit -m "feat: initial Mineshark infrastructure setup

- K3s manifests for Velocity, Lobby, Survie, Dev servers
- GeyserMC crossplay configuration
- GitHub Actions CI/CD pipeline
- Backup scripts and monitoring"

git remote add origin git@github.com:TON_USER/mineshark.git
git push -u origin main
```

---

## 13. CI/CD avec GitHub Actions

### 13.1 Comment ça marche

Le flow :
1. Tu push des changements sur GitHub (ex: modifier un deployment YAML)
2. GitHub Actions détecte le push
3. Le workflow valide les fichiers YAML (lint)
4. Si c'est sur `main`, il déploie automatiquement sur ton VPS via SSH
5. kubectl apply les changements

### 13.2 Secrets GitHub

Va dans ton repo GitHub → Settings → Secrets and variables → Actions.
Ajoute ces secrets :

| Nom | Valeur |
|-----|--------|
| `VPS_HOST` | L'IP de ton VPS |
| `VPS_USER` | `mineshark` |
| `VPS_SSH_KEY` | Le contenu de ta clé privée SSH (`cat ~/.ssh/id_ed25519`) |
| `KUBECONFIG_DATA` | Le contenu de `~/.kube/config` encodé en base64 |

Pour encoder le kubeconfig :

```bash
cat ~/.kube/config | base64 -w 0
# Copie le résultat dans le secret GitHub KUBECONFIG_DATA
```

### 13.3 Workflow de Déploiement

Crée `.github/workflows/deploy.yml` :

```yaml
name: Deploy Mineshark

on:
  push:
    branches: [main]
    paths:
      - 'k8s/**'
      - 'configs/**'
  
  # Permet de lancer manuellement depuis GitHub
  workflow_dispatch:
    inputs:
      component:
        description: 'Component to deploy (all, velocity, lobby, survie, dev)'
        required: true
        default: 'all'

jobs:
  # Job 1 : Validation
  validate:
    name: Validate YAML
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install kubeval
        run: |
          wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
          tar xf kubeval-linux-amd64.tar.gz
          sudo mv kubeval /usr/local/bin/
      
      - name: Validate K8s manifests
        run: |
          find k8s/ -name "*.yaml" -o -name "*.yml" | while read file; do
            echo "Validating $file..."
            kubeval "$file" --strict || true
          done
  
  # Job 2 : Déploiement
  deploy:
    name: Deploy to VPS
    needs: validate
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup kubectl
        run: |
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/
      
      - name: Configure kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_DATA }}" | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config
      
      - name: Deploy to K3s
        run: |
          COMPONENT="${{ github.event.inputs.component || 'all' }}"
          
          if [ "$COMPONENT" = "all" ]; then
            echo "=== Deploying ALL components ==="
            kubectl apply -f k8s/base/
            kubectl apply -f k8s/velocity/
            kubectl apply -f k8s/lobby/
            kubectl apply -f k8s/survie/
            kubectl apply -f k8s/dev/
          else
            echo "=== Deploying $COMPONENT ==="
            kubectl apply -f k8s/base/
            kubectl apply -f k8s/$COMPONENT/
          fi
      
      - name: Verify deployment
        run: |
          echo "=== Pod Status ==="
          kubectl -n mineshark get pods
          echo ""
          echo "=== Services ==="
          kubectl -n mineshark get services
      
      - name: Wait for rollout
        run: |
          COMPONENT="${{ github.event.inputs.component || 'all' }}"
          
          if [ "$COMPONENT" = "all" ] || [ "$COMPONENT" = "velocity" ]; then
            kubectl -n mineshark rollout status deployment/velocity --timeout=120s || true
          fi
          if [ "$COMPONENT" = "all" ] || [ "$COMPONENT" = "lobby" ]; then
            kubectl -n mineshark rollout status deployment/mc-lobby --timeout=180s || true
          fi
          if [ "$COMPONENT" = "all" ] || [ "$COMPONENT" = "survie" ]; then
            kubectl -n mineshark rollout status deployment/mc-survie --timeout=300s || true
          fi
```

### 13.4 Workflow de Lint

Crée `.github/workflows/lint.yml` :

```yaml
name: Lint

on:
  pull_request:
    branches: [main]

jobs:
  yaml-lint:
    name: YAML Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install yamllint
        run: pip install yamllint
      
      - name: Run yamllint
        run: |
          yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" k8s/
```

### 13.5 Workflow de Backup

Crée `.github/workflows/backup.yml` :

```yaml
name: Backup Minecraft Worlds

on:
  schedule:
    # Tous les jours à 4h du matin (UTC)
    - cron: '0 4 * * *'
  workflow_dispatch:

jobs:
  backup:
    name: Backup Worlds
    runs-on: ubuntu-latest
    
    steps:
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.VPS_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H ${{ secrets.VPS_HOST }} >> ~/.ssh/known_hosts
      
      - name: Run backup script
        run: |
          ssh -i ~/.ssh/id_ed25519 ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }} << 'SCRIPT'
            #!/bin/bash
            set -e
            
            BACKUP_DIR="/home/mineshark/backups"
            DATE=$(date +%Y-%m-%d_%H-%M)
            
            mkdir -p $BACKUP_DIR
            
            echo "=== Backing up Lobby ==="
            kubectl -n mineshark exec deployment/mc-lobby -- \
              tar czf - /data/world /data/world_nether /data/world_the_end 2>/dev/null \
              > "$BACKUP_DIR/lobby-$DATE.tar.gz" || echo "Lobby backup skipped"
            
            echo "=== Backing up Survie ==="
            kubectl -n mineshark exec deployment/mc-survie -- \
              tar czf - /data/world /data/world_nether /data/world_the_end 2>/dev/null \
              > "$BACKUP_DIR/survie-$DATE.tar.gz" || echo "Survie backup skipped"
            
            echo "=== Cleaning old backups (keep 7 days) ==="
            find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
            
            echo "=== Backup complete ==="
            ls -lh $BACKUP_DIR/
          SCRIPT
```

### 13.6 Flow de travail quotidien

Voilà comment tu vas travailler au quotidien :

```bash
# 1. Tu veux modifier la config du lobby
git checkout -b feat/lobby-pvp-arena

# 2. Tu édites le deployment
nano k8s/lobby/deployment.yaml

# 3. Tu commit et push
git add k8s/lobby/deployment.yaml
git commit -m "feat(lobby): add PVP arena configuration"
git push origin feat/lobby-pvp-arena

# 4. Tu crées une Pull Request sur GitHub
# → Le workflow lint.yml vérifie tes YAML
# → Tu review et merge

# 5. Le merge sur main déclenche deploy.yml
# → Tes changements sont appliqués automatiquement sur le VPS
```

---

## 14. Monitoring & Backups

### 14.1 Monitoring basique avec kubectl

```bash
# État de tous les pods
kubectl -n mineshark get pods -o wide

# Consommation mémoire/CPU
kubectl -n mineshark top pods

# Logs en temps réel d'un serveur
kubectl -n mineshark logs -f deployment/mc-lobby
kubectl -n mineshark logs -f deployment/mc-survie
kubectl -n mineshark logs -f deployment/velocity

# Événements (utile pour debug)
kubectl -n mineshark get events --sort-by='.lastTimestamp'
```

### 14.2 Script de monitoring simple

Crée `scripts/status.sh` :

```bash
#!/bin/bash
# scripts/status.sh — État rapide du réseau Mineshark

echo "=============================="
echo "  MINESHARK STATUS"
echo "  $(date)"
echo "=============================="
echo ""

echo "--- PODS ---"
kubectl -n mineshark get pods -o wide
echo ""

echo "--- RESOURCES ---"
kubectl -n mineshark top pods 2>/dev/null || echo "(metrics-server not installed)"
echo ""

echo "--- SERVICES ---"
kubectl -n mineshark get svc
echo ""

echo "--- DISK USAGE ---"
df -h | head -5
echo ""

echo "--- MEMORY ---"
free -h
echo ""

echo "--- PLAYER COUNT (via RCON) ---"
for server in mc-lobby mc-survie mc-dev; do
  PLAYERS=$(kubectl -n mineshark exec deployment/$server -- rcon-cli list 2>/dev/null | head -1)
  echo "  $server: $PLAYERS"
done
```

```bash
chmod +x scripts/status.sh
```

### 14.3 Backup manuel rapide

```bash
# Backup du monde survie avant un changement risqué
kubectl -n mineshark exec deployment/mc-survie -- \
  tar czf /tmp/backup-survie.tar.gz /data/world

# Copie le backup sur ta machine
kubectl -n mineshark cp mineshark/$(kubectl -n mineshark get pod -l app=mc-survie -o jsonpath='{.items[0].metadata.name}'):/tmp/backup-survie.tar.gz ./backup-survie.tar.gz
```

---

## 15. Commandes Utiles K3s

### Gestion des Pods

```bash
# Lister les pods
kubectl -n mineshark get pods

# Voir les détails d'un pod (debug)
kubectl -n mineshark describe pod <NOM_DU_POD>

# Entrer dans un conteneur (shell)
kubectl -n mineshark exec -it deployment/mc-lobby -- bash

# Exécuter une commande Minecraft via RCON
kubectl -n mineshark exec -it deployment/mc-lobby -- rcon-cli
# Puis tape des commandes comme: list, op <player>, gamemode creative <player>

# Redémarrer un serveur proprement
kubectl -n mineshark rollout restart deployment/mc-lobby

# Forcer la suppression d'un pod stuck
kubectl -n mineshark delete pod <NOM_DU_POD> --force --grace-period=0
```

### Gestion des Déploiements

```bash
# Voir l'historique des déploiements
kubectl -n mineshark rollout history deployment/mc-lobby

# Revenir à la version précédente (rollback)
kubectl -n mineshark rollout undo deployment/mc-lobby

# Mettre à l'échelle (0 = éteindre)
kubectl -n mineshark scale deployment/mc-dev --replicas=0
kubectl -n mineshark scale deployment/mc-dev --replicas=1
```

### Gestion des Volumes

```bash
# Voir les PVC
kubectl -n mineshark get pvc

# Voir l'espace utilisé
kubectl -n mineshark exec deployment/mc-survie -- du -sh /data/
```

### Debug

```bash
# Pourquoi un pod ne démarre pas ?
kubectl -n mineshark describe pod <NOM_DU_POD>
# Regarde la section "Events" en bas

# Logs d'un pod crash
kubectl -n mineshark logs <NOM_DU_POD> --previous

# Tous les événements du namespace
kubectl -n mineshark get events --sort-by='.lastTimestamp' | tail -20
```

---

## 16. Roadmap & Next Steps

### Phase 1 — Infrastructure (Ce guide)
- [x] Architecture réseau
- [ ] Setup VPS Hetzner
- [ ] Installation K3s
- [ ] Déploiement Velocity + GeyserMC
- [ ] Déploiement Lobby Paper
- [ ] Déploiement Survie NeoForge
- [ ] Déploiement Dev/Sandbox
- [ ] CI/CD GitHub Actions
- [ ] Backups automatiques

### Phase 2 — Plugins & Gameplay
- [ ] Plugins lobby (système de portails, minijeux)
- [ ] Plugins essentiels (EssentialsX, LuckPerms, WorldGuard)
- [ ] Configuration des permissions
- [ ] Maps custom pour les minijeux

### Phase 3 — Site Web & CMS
- [ ] CMS Minecraft custom (Next.js + NestJS)
- [ ] Authentification (lien compte Minecraft)
- [ ] Dashboard joueurs (stats, classements)
- [ ] Panel admin (RCON web, gestion serveurs)
- [ ] Intégration K8s API pour status serveurs

### Phase 4 — Automatisation Avancée
- [ ] Monitoring avancé (Prometheus + Grafana)
- [ ] Alertes Discord (serveur down, backup fail)
- [ ] Auto-scaling dev serveurs
- [ ] Domaine custom (play.mineshark.fr)
- [ ] Certificat SSL pour le site

### Phase 5 — Hytale (Quand disponible)
- [ ] Serveur Hytale dans le même cluster K3s
- [ ] Intégration dans le CMS/site
- [ ] Cross-lobby Minecraft/Hytale

---

## Sources & Références

- [PaperMC — Velocity Proxy](https://papermc.io/software/velocity/)
- [PaperMC — Pourquoi Velocity](https://docs.papermc.io/velocity/why-velocity/)
- [GeyserMC — Crossplay Java/Bedrock](https://geysermc.org/)
- [itzg/docker-minecraft-server — Image Docker](https://github.com/itzg/docker-minecraft-server)
- [K3s — Documentation officielle](https://docs.k3s.io/)
- [Hetzner Cloud — VPS](https://www.hetzner.com/cloud/)
- [Modded Together — Modpack CurseForge](https://www.curseforge.com/minecraft/modpacks/moddedtogether)
- [Paper vs Purpur vs Spigot 2026](https://pinehosting.com/blog/paper-vs-purpur-vs-spigot-in-2026-which-is-best-for-performance-and-plugins/)
- [Velocity vs BungeeCord 2026](https://space-node.net/blog/bungeecord-vs-velocity-proxy-2026)
- [Hetzner Cloud Review 2026](https://betterstack.com/community/guides/web-servers/hetzner-cloud-review/)
