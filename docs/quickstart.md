# Quickstart MineShark

Tutoriel pas-à-pas pour avoir un serveur fonctionnel en 5 minutes.

---

## En local (Docker Compose)

Pré-requis : Docker installé, ~6 Go RAM disponibles.

```bash
# 1. Clone et entre dans le dossier
git clone <url-repo> mineshark
cd mineshark

# 2. Initialise la structure, la config et les secrets auto-générés
make init
# → ça crée .env, data/, backups/, data/secrets/rcon.secret
#   et data/velocity/forwarding.secret (openssl rand -hex 16 chacun)

# 3. Édite .env si besoin (une seule clé à remplir à la main) :
$EDITOR .env
#   - CF_API_KEY  : ta clé CurseForge si tu veux le moddé
#                   (https://console.curseforge.com/?#/api-keys)
#                   Laisse "change-me" pour désactiver le moddé.

# 4. Vérifie que tout est en place
make doctor

# 5. Démarre la stack (proxy + serveur principal)
make docker-up

# 6. Surveille les logs
make docker-logs
```

Pour voir les secrets auto-générés (utile pour un outil RCON externe) :

```bash
make show-secrets
```

Connexion :
- **Java** : `localhost:25565`
- **Bedrock** : `localhost:19132`
- **Moddé** (si activé) : `localhost:25566` — serveur standalone, ne passe pas par le proxy

Pour le serveur moddé optionnel (lourd, 3 Go RAM minimum en dev) :

```bash
make docker-mod-up
```

---

## En production (VPS avec K3s)

Pré-requis : voir [`vps-setup.md`](vps-setup.md) pour l'install initiale du VPS et de K3s.

```bash
# 1. Clone sur le VPS
ssh mineshark@<ton-ip>
git clone <url-repo> mineshark
cd mineshark

# 2. Init + édite .env (mêmes valeurs que ci-dessus)
make init
nano .env

# 3. Déploie
make up
```

Vérifier le déploiement :

```bash
make status
```

Tu dois voir :
- Pods `velocity-xxx`, `mc-main-xxx` en état `Running`
- Service `velocity` avec une `EXTERNAL-IP` = ton IP publique du VPS

À ce moment, tu peux te connecter avec ton client Minecraft sur cette IP, port `25565`.

---

## Commandes du quotidien

| Commande | Effet |
|---|---|
| `make help` | Liste toutes les commandes |
| `make status` | État pods/services/volumes |
| `make logs-proxy` | Suit les logs Velocity |
| `make logs-main` | Suit les logs serveur principal |
| `make rcon-main` | Console RCON serveur principal |
| `make mod-on` | Démarre le moddé |
| `make mod-off` | Arrête le moddé |
| `make backup` | Snapshot manuel des données |

---

## Workflow de modification

1. Tu modifies du code en local
2. `make doctor` vérifie qu'il n'y a pas d'erreur évidente
3. `make docker-re` teste localement
4. `git add ... && git commit ... && git push`
5. `make deploy` (push git + pull VPS + make re automatique)

---

## Quand quelque chose ne va pas

- **`make up` plante** → lance `kubectl describe pod <nom-pod> -n mineshark` pour la cause exacte
- **Pas d'IP externe sur Velocity** → le firewall du VPS bloque 25565/19132 (UDP). Voir `vps-setup.md`
- **Pas d'IP externe sur mc-mod** → même chose, ouvre le port 25566 TCP sur le VPS
- **Le proxy démarre mais le serveur principal ne peut pas joindre** → vérifier que `velocity-forwarding-secret` est synchronisé entre proxy et backends (`make secrets` puis `make re`)
- **Modpack ne télécharge pas** → vérifier `CF_API_KEY` valide + `MODPACK_SLUG` existe sur curseforge.com
- **Port 19132 déjà alloué** → c'est souvent un cluster k3d encore vivant : `docker ps | grep k3d-` puis `k3d cluster delete <nom>` ou `docker stop k3d-<nom>-serverlb`
