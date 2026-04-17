# MineShark — Guide Setup VPS Netcup RS 2000 G12

> Debian 12 Bookworm + K3s + MineShark
> Processeur dédié AMD EPYC, 16 Go RAM, 320 Go SSD

---

## 1. Premier accès — Interface Netcup

### 1.1 Customer Control Panel (CCP)

C'est ton tableau de bord client général. URL : **https://www.customercontrolpanel.de**

Tu y trouves : facturation, produits, DNS, domaines. Les identifiants arrivent par mail après commande (sujet : "Zugangsdaten CCP").

### 1.2 Server Control Panel (SCP)

C'est le panneau de gestion de ton serveur physique. URL : **https://www.servercontrolpanel.de**

Les identifiants arrivent dans un mail séparé (sujet : "Zugangsdaten SCP"). C'est ici que tu :
- Démarres/arrêtes/redémarres le serveur
- Installes un OS (image)
- Gères les clés SSH
- Accèdes à la console VNC (accès d'urgence si SSH ne marche plus)
- Crées des snapshots (instantanés) du serveur

### 1.3 Installer Debian 12

1. Connecte-toi au SCP
2. Va dans **Media** → **Images**
3. Sélectionne **Debian 12 (Bookworm) minimal**
4. **AVANT d'installer** : va dans **Options** → **SSH Keys** → ajoute ta clé publique SSH
   - Sur ton PC : `cat ~/.ssh/id_ed25519.pub` (ou `id_rsa.pub`)
   - Si tu n'en as pas : `ssh-keygen -t ed25519 -C "mineshark"`
   - Colle la clé publique dans le SCP
5. Lance l'installation — ça prend 2-5 minutes
6. Note l'IP du serveur affichée dans le SCP (ex: `89.58.xxx.xxx`)

---

## 2. Première connexion SSH

```bash
# Depuis ton PC (WSL2)
ssh root@89.58.xxx.xxx
```

Si tu as ajouté ta clé SSH au SCP, pas besoin de mot de passe. Sinon, le mot de passe root est dans le mail SCP.

### 2.1 Sécurisation immédiate

```bash
# Mettre à jour
apt update && apt upgrade -y

# Changer le mot de passe root (même si tu utilises SSH keys)
passwd

# Installer les outils de base
apt install -y curl wget git ufw fail2ban htop

# Configurer le hostname (nom d'hôte)
hostnamectl set-hostname mineshark
echo "127.0.1.1 mineshark" >> /etc/hosts
```

### 2.2 Créer un utilisateur non-root

```bash
# Créer l'utilisateur
adduser mineshark
# Ajouter au groupe sudo
usermod -aG sudo mineshark

# Copier la clé SSH
mkdir -p /home/mineshark/.ssh
cp ~/.ssh/authorized_keys /home/mineshark/.ssh/
chown -R mineshark:mineshark /home/mineshark/.ssh
chmod 700 /home/mineshark/.ssh
chmod 600 /home/mineshark/.ssh/authorized_keys

# Tester dans un AUTRE terminal AVANT de verrouiller root
ssh mineshark@89.58.xxx.xxx
sudo whoami   # doit afficher "root"
```

### 2.3 Sécuriser SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Modifie ces lignes :
```
Port 2222                     # Change le port par défaut (évite 90% des bots)
PermitRootLogin no            # Interdit la connexion root
PasswordAuthentication no     # Clé SSH obligatoire
MaxAuthTries 3
```

```bash
sudo systemctl restart sshd

# Reconnecte-toi avec le nouveau port
ssh -p 2222 mineshark@89.58.xxx.xxx
```

### 2.4 Firewall (pare-feu)

```bash
# Port SSH custom
sudo ufw allow 2222/tcp

# Minecraft Java
sudo ufw allow 25565/tcp

# Minecraft Bedrock
sudo ufw allow 19132/udp

# HTTP/HTTPS (pour le futur site web)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# K3s API (si tu veux administrer depuis ton PC — optionnel)
# sudo ufw allow 6443/tcp

# Activer
sudo ufw enable
sudo ufw status
```

### 2.5 Fail2ban (protection brute-force)

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled = true
port = 2222
maxretry = 3
bantime = 3600
findtime = 600
```

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## 3. Installer K3s (pas k3d — on est en prod)

En prod sur un VPS dédié, on installe K3s directement (pas k3d qui est pour le dev local). K3s utilise containerd nativement — pas besoin d'installer Docker.

```bash
# Installation K3s (single-node, sans Traefik — on l'ajoutera si besoin)
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --write-kubeconfig-mode 644

# Vérifier
sudo systemctl status k3s
sudo kubectl get nodes
# Tu devrais voir : mineshark   Ready   control-plane,master
```

### 3.1 Configurer kubectl

```bash
# K3s génère le kubeconfig ici
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Ajouter au .bashrc pour que ce soit permanent
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

# Alias pratique
echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

# Test
k get nodes
```

### 3.2 Administrer depuis ton PC (optionnel)

Si tu veux faire `kubectl` et `make` depuis WSL2 sur ton PC :

```bash
# Sur le VPS — copie le kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# Sur ton PC — colle dans ~/.kube/config
mkdir -p ~/.kube
nano ~/.kube/config
# Remplace "127.0.0.1" par l'IP du VPS (89.58.xxx.xxx)
# Remplace "default" par "mineshark" dans le nom du context si tu veux
```

---

## 4. Déployer MineShark

### 4.1 Cloner le repo

```bash
# Sur le VPS
cd /opt
sudo git clone https://github.com/zoyern/mineshark.git
sudo chown -R mineshark:mineshark /opt/mineshark
cd /opt/mineshark
```

### 4.2 Configurer les secrets

```bash
# Copier le template
cp .env.example .env
nano .env
# Remplir CF_API_KEY et RCON_PASSWORD avec des vrais mots de passe

# Générer le forwarding secret Velocity
mkdir -p data/velocity
openssl rand -hex 16 > data/velocity/forwarding.secret
```

### 4.3 Adapter le service Velocity pour la prod

En prod (K3s natif), pas besoin de k3d loadbalancer. Le Service NodePort expose directement sur le serveur.

Tu dois modifier `k8s/velocity/service.yaml` sur le VPS :

```yaml
# En prod, les NodePorts sont directement accessibles
# Change les nodePort pour matcher les ports standards MC
# OU utilise HostPort dans le deployment à la place
```

**Option simple (HostPort)** — ajoute `hostPort` dans le deployment Velocity :
```yaml
ports:
  - containerPort: 25577
    hostPort: 25565      # Joueurs se connectent sur :25565
    protocol: TCP
  - containerPort: 19132
    hostPort: 19132      # Bedrock direct
    protocol: UDP
```

Et change le service en ClusterIP (plus besoin de NodePort) :
```yaml
spec:
  type: ClusterIP    # au lieu de NodePort
  # retire les lignes nodePort
```

### 4.4 Déployer

```bash
cd /opt/mineshark

# Créer le namespace + secrets + deploy
make secrets
make up

# Vérifier
make status

# Suivre les logs Velocity
make logs-proxy
```

### 4.5 Tester la connexion

Depuis Minecraft :
- **Java** : `89.58.xxx.xxx` (port 25565 par défaut)
- **Bedrock** : `89.58.xxx.xxx` port `19132`

---

## 5. Récupérer les maps SkulyCube

Tes anciennes maps sont dans `mc-server-old/`. Pour les importer dans Paper :

```bash
# Sur le VPS, copie le lobby dans le PVC de Paper
# D'abord, trouve le chemin du PVC
kubectl -n mineshark get pvc server-main-pvc -o jsonpath='{.spec.volumeName}'

# Copie via kubectl cp (le pod doit tourner)
# La map lobby deviendra un monde multiverse
kubectl cp mc-server-old/lobby mineshark/mc-main-xxx:/data/lobby
kubectl cp mc-server-old/sw1 mineshark/mc-main-xxx:/data/sw1
# etc. (remplace mc-main-xxx par le vrai nom du pod)
```

Ensuite installe les plugins pour gérer les mondes :
- **Multiverse-Core** : gérer plusieurs mondes
- **Multiverse-Portals** : portails entre les mondes

Tu les ajouteras via la variable PLUGINS dans le deployment main.

---

## 6. Budget RAM prod (16 Go)

| Composant | RAM |
|-----------|-----|
| OS Debian + K3s + containerd | ~800 Mo |
| Velocity (proxy) | 512 Mo |
| Paper Main (survie + lobby + maps) | 3 Go |
| NeoForge Moddé (Modded Together) | 6 Go |
| Site web (futur) | 512 Mo |
| Backup container | 256 Mo |
| **Total** | **~11 Go** |
| **Marge restante** | **~5 Go** (cache OS, pics de charge) |

---

## 7. Monitoring et maintenance

### Commandes utiles

```bash
# État du cluster
make status

# Logs en temps réel
make logs-proxy
make logs-main
make logs-mod

# Redémarrer un serveur sans perdre les données
make restart-main
make restart-proxy

# Allumer/éteindre le moddé
make mod-on
make mod-off

# Usage RAM/CPU en temps réel
kubectl -n mineshark top pods
htop   # sur le VPS directement
```

### Backups automatiques

Le backup est géré par `itzg/mc-backup` dans le docker-compose. Pour K3s, tu ajouteras un CronJob (tâche planifiée) K8s plus tard. En attendant, script cron basique :

```bash
# /opt/mineshark/scripts/backup.sh
#!/bin/bash
BACKUP_DIR="/opt/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# Pause le serveur via RCON avant la copie
kubectl -n mineshark exec deployment/mc-main -- rcon-cli save-off
kubectl -n mineshark exec deployment/mc-main -- rcon-cli save-all

# Copie les données du PVC
kubectl cp mineshark/$(kubectl -n mineshark get pod -l app=mc-main -o name | head -1 | sed 's|pod/||'):/data "$BACKUP_DIR/main"

# Reprend les sauvegardes auto
kubectl -n mineshark exec deployment/mc-main -- rcon-cli save-on

# Supprime les backups > 7 jours
find /opt/backups -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
```

```bash
chmod +x /opt/mineshark/scripts/backup.sh
# Crontab — tous les jours à 4h du matin
echo "0 4 * * * /opt/mineshark/scripts/backup.sh" | crontab -
```

---

## 8. Checklist sécurité

- [ ] SSH sur port custom (pas 22)
- [ ] Root login désactivé
- [ ] Password auth désactivé (clés SSH uniquement)
- [ ] UFW activé (seuls ports 2222, 25565, 19132, 80, 443)
- [ ] Fail2ban configuré
- [ ] Utilisateur non-root créé
- [ ] .env avec vrais secrets (pas les valeurs d'exemple)
- [ ] forwarding.secret généré (pas "CHANGE_ME")
- [ ] RCON pas exposé sur le réseau (ClusterIP only)
- [ ] Snapshots SCP réguliers (1/semaine minimum)
