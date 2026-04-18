# api/ — Backend MineShark (Phase 4)

> **Statut : stub.** Ce dossier sera rempli Phase 4.

---

## Stack prévue

- **NestJS 11** — framework Node.js structuré (DI, controllers, modules)
- **TypeScript strict**
- **Prisma** — ORM + migrations
- **PostgreSQL 17** — base principale (stats joueurs, shop, posts)
- **Redis** — cache + sessions + pub/sub
- **WebSockets** (gateway NestJS) — statut serveur temps réel, chat Discord ↔ MC

## Endpoints / Modules à prévoir

| Module | Rôle | Dépendances |
|---|---|---|
| `auth` | Échange OAuth Microsoft + validation pseudo MC | NextAuth côté Next |
| `players` | Stats (kills, wins, connexions), profil public | Prisma |
| `status` | Statut live proxy + serveurs (ping MC via `mc-monitor`) | WS |
| `shop` | Boutique cosmétique (points gagnés en jeu) | Prisma |
| `blog` | CRUD posts admin | Prisma + S3 pour images |
| `discord-bridge` | Relay chat MC ↔ salon Discord | bot Discord (plugin MC côté serveur) |

## Interaction avec les serveurs MC

Plusieurs canaux selon le besoin :

- **RCON** : lecture ponctuelle (joueurs online, exécution de commandes admin)
- **Plugin-bridge** (à écrire) : plugin custom côté Paper qui push stats + events
  via Redis (channel `minecraft.events`) → NestJS consume
- **mc-monitor** : ping UDP/TCP pour uptime (pas besoin de plugin)

## Déploiement

- Build NestJS en image Docker
- Déployé sur K3s (Deployment + Service ClusterIP)
- Exposé via Nginx Ingress (sous-chemin `/api` du domaine principal)

## Prochaines étapes

```bash
# Stub — ne PAS exécuter tant que le serveur n'est pas stable
cd api/
npx @nestjs/cli new . --skip-git --package-manager=pnpm
pnpm add @prisma/client
pnpm add -D prisma
npx prisma init
```
