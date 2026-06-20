# Lago Helm chart

Kubernetes deploy for Lago (API, front, Sidekiq workers, clock, PDF). Validated by
`../../../repo-gates/deploy-check.sh` (`make deploy-check`). Every image tag is
pinned — no `:latest`.

> Billing data belongs in **managed Postgres/Redis**. This chart expects them to be
> external and reached via `DATABASE_URL` / `REDIS_URL` in a Secret you create.

## 1. Create the secret (never put these in `values.yaml`)

```bash
kubectl create secret generic lago-secrets \
  --from-literal=DATABASE_URL='postgresql://lago:***@db-host:5432/lago?search_path=public' \
  --from-literal=REDIS_URL='redis://redis-host:6379' \
  --from-literal=SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  --from-literal=LAGO_RSA_PRIVATE_KEY="$(openssl genrsa 2048 | openssl base64 -A)" \
  --from-literal=LAGO_ENCRYPTION_PRIMARY_KEY="$(openssl rand -hex 16)" \
  --from-literal=LAGO_ENCRYPTION_DETERMINISTIC_KEY="$(openssl rand -hex 16)" \
  --from-literal=LAGO_ENCRYPTION_KEY_DERIVATION_SALT="$(openssl rand -hex 16)"
```

The Secret name is `existingSecret` in `values.yaml` (default `lago-secrets`).

## 2. Validate, then install

```bash
helm lint deploy/helm/lago
helm template lago deploy/helm/lago | less        # eyeball the manifests
helm upgrade --install lago deploy/helm/lago \
  --namespace lago --create-namespace \
  --set domain=billing.yourcompany.com
```

A `pre-install`/`pre-upgrade` Job runs `./scripts/migrate.sh` before new pods take
traffic (`migrate.enabled=true`).

## 3. Verify it actually answers (not just "Running")

```bash
kubectl -n lago rollout status deploy/lago-lago-api
kubectl -n lago exec deploy/lago-lago-api -- curl -fsS http://localhost:3000/health
```

## What gets created

| Workload | Notes |
|---|---|
| `*-api` Deployment + Service | `getlago/api`, port 3000, liveness/readiness on `/health` |
| `*-front` Deployment + Service | `getlago/front`, port 80 |
| `*-<worker>` Deployments | one per entry in `values.yaml: workers` (Sidekiq) |
| `*-clock` Deployment | singleton scheduler (`replicas: 1`, `Recreate`) |
| `*-pdf` Deployment + Service | Gotenberg, toggle with `pdf.enabled` |
| `*-migrate` Job | pre-install/upgrade hook |
| `Ingress` | `/api`,`/graphql`,`/rails` → API; `/` → front |
| `ConfigMap` | non-secret env (URLs, `RAILS_ENV`, …) |

## Key values

| Key | Default | Meaning |
|---|---|---|
| `domain` | `billing.example.com` | builds URLs + Ingress host |
| `image.api.tag` | `v1.27.1` | **pinned** API image |
| `image.front.tag` | `v1.27.1` | **pinned** front image |
| `existingSecret` | `lago-secrets` | Secret with DB/Redis/crypto |
| `workers` | 5 roles | Sidekiq roles + concurrency/pool |
| `ingress.className` | `nginx` | set to your controller |

Override at install with `--set` or a `-f my-values.yaml`.
