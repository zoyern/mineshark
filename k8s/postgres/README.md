# k8s/postgres/ — PostgreSQL pour le site web (Phase 4)

> **Statut : stub.** À déployer uniquement quand le site démarre.

---

## Choix d'implémentation

### Option 1 — Bitnami Helm (recommandé)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql \
  --namespace mineshark \
  --set auth.database=mineshark \
  --set auth.username=mineshark \
  --set auth.existingSecret=postgres-secret \
  --set persistence.size=5Gi
```

**Avantages** : battle-tested, backups intégrés, chaîné à une instance read-replica facilement.

### Option 2 — Manifestes plats (contrôle total)

Fichiers à créer dans ce dossier :

- `deployment.yaml` — image `postgres:17-alpine`, probes, resources
- `service.yaml` — ClusterIP sur 5432
- `pvc.yaml` — 5Gi (longhorn ou local-path K3s)
- `secret.yaml.template` — `POSTGRES_PASSWORD` (valeur générée via `make init` → `data/secrets/postgres.secret`)

**Avantages** : pas de dépendance Helm, tout dans git.

## Accès depuis l'API

Depuis `api/` (NestJS), DSN :

```
postgresql://mineshark:<password>@postgres:5432/mineshark
```

Le mot de passe sera lu depuis la Kubernetes Secret `postgres-secret`, montée en env var `DATABASE_URL` dans le Deployment NestJS.

## Backups

- CronJob quotidien qui fait `pg_dump` → stockage S3 (backup blaze ou Scaleway Object Storage)
- Rétention 30 jours glissants + 1 par mois sur 12 mois

## Monitoring

Exporter prometheus-postgres-exporter → Grafana dashboard 9628.

## À décider quand on arrive Phase 4

- Helm vs YAML plat (préférence actuelle : Helm pour le gain de maintenance)
- High-availability (une seule instance suffit au début)
- Localisation des backups (Scaleway pour rester FR/EU)
