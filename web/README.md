# web/ — Site public MineShark (Phase 4)

> **Statut : stub.** Ce dossier sera rempli Phase 4 (post-lancement serveur).

---

## Stack prévue

- **Next.js 15** (App Router, Server Components, Turbopack)
- **TypeScript strict**
- **Tailwind 4** + [shadcn/ui](https://ui.shadcn.com/) pour le design
- **NextAuth v5** — auth via compte Minecraft/Microsoft + Discord OAuth
- **tRPC** côté client pour parler à l'API NestJS (`api/`)
- **React Query** pour le cache côté client

## Contenu du site (prioritisé)

1. **Accueil** — IP du serveur, statut en live (players online, uptime), MOTD
2. **Vote** — intégrations avec les top-lists FR (MCServers.com, Minecraft-FR)
3. **Boutique cosmétique** — système de points obtenus par le jeu (pas d'argent réel — pay-to-win interdit)
4. **Leaderboards** — stats Skywars (kills, wins, streak)
5. **Blog** — news du serveur
6. **Discord widget** — lien vers le Discord MineShark

## Déploiement

- Build Next en container (`Dockerfile` multi-stage avec output `standalone`)
- Exposé via **Nginx Ingress Controller** sur K3s (sous-domaine `mineshark.fr`)
- Base de données PostgreSQL partagée avec l'API (voir `../api/` et `../k8s/postgres/`)

## Prochaines étapes (quand Phase 4 démarre)

```bash
# Stub — ne PAS exécuter tant que le serveur n'est pas stable
cd web/
npx create-next-app@latest . --ts --tailwind --app --src-dir --import-alias "@/*"
npx shadcn@latest init
npm i next-auth@beta @trpc/client @trpc/react-query zod
```

Voir [`docs/architecture.md`](../docs/architecture.md) § Phase 4 pour le diagramme cible.
