# k8s/ingress/ — Nginx Ingress Controller (Phase 4)

> **Statut : stub.** À déployer avant/avec le site web.

---

## Pourquoi Nginx Ingress et pas Traefik ?

K3s inclut **Traefik** par défaut. On garde Traefik désactivé pour :
- cohérence de la stack avec l'écosystème Next.js / NestJS (tutos majoritairement Nginx),
- maîtrise fine des timeouts WebSocket (NestJS) et des upgrades HTTP/2.

**Attention** : Minecraft ne passe **pas** par l'ingress. Les Services Velocity et mc-mod restent en `type: LoadBalancer` car le protocole Minecraft (TCP/UDP custom) n'est pas routable par un ingress HTTP.

## Install rapide

```bash
# Disable Traefik au boot K3s (une seule fois sur le VPS) :
# ajouter --disable traefik à INSTALL_K3S_EXEC
# cf. docs/vps-setup.md

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer
```

## Fichiers à créer ici

- `ingress-web.yaml` — route `mineshark.fr` → service Next.js
- `ingress-api.yaml` — route `mineshark.fr/api` → service NestJS
- `cert-manager-issuer.yaml` — Let's Encrypt via [cert-manager](https://cert-manager.io/)

## TLS

cert-manager + Let's Encrypt (ACME) → certificats auto-renouvelés tous les 60 jours.

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

## À décider quand on arrive Phase 4

- Domaine : `mineshark.fr` (à checker dispo) ou sous-domaine OVH existant
- CDN devant (Cloudflare orange cloud) : bonne idée pour DDoS HTTP, mais ⚠️ attention à ne **pas** proxy les ports Minecraft (25565) car ça tue le handshake.
