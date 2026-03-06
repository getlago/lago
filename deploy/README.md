# Lago Deploy

This directory contains deployment templates for self-hosting Lago with Docker Compose, including VPS and reverse-proxy friendly setups.

## Deployment modes

| Mode | Best for | SSL / Reverse proxy | Files |
| --- | --- | --- | --- |
| Quickstart | Fast evaluation on one host | No | `docker run` |
| Local | Local testing and staging | No | `docker-compose.local.yml` |
| Light | Small production workloads | Yes (Traefik + Let's Encrypt) | `docker-compose.light.yml` + `.env.light.example` |
| Production | Higher throughput production | Yes (Traefik + Let's Encrypt) | `docker-compose.production.yml` + `.env.production.example` |

## Prerequisites

1. Docker engine installed
2. Docker Compose (`docker compose` plugin or `docker-compose`)
3. For `Light` and `Production`: a public domain with valid DNS A/AAAA records
4. For `Light` and `Production`: ports `80` and `443` reachable from the internet

## Option A: Interactive deploy script

Use the guided deploy script when you want the quickest path on a VPS:

```bash
curl -fsSL -o deploy.sh https://raw.githubusercontent.com/getlago/lago/main/deploy/deploy.sh
bash deploy.sh
```

The script lets you choose the deployment mode, downloads the right files, asks for required environment variables, and starts the stack.

## Option B: Manual Docker Compose deployment

### Local mode

```bash
curl -fsSL -o docker-compose.local.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.local.yml
docker compose -f docker-compose.local.yml up -d --profile all
```

### Light mode (VPS + reverse proxy + TLS)

```bash
curl -fsSL -o docker-compose.light.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.light.yml
curl -fsSL -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.light.example
```

Set `.env`:

```bash
LAGO_DOMAIN=billing.example.com
LAGO_ACME_EMAIL=infra@example.com
```

Run:

```bash
docker compose -f docker-compose.light.yml up -d --profile all
```

### Production mode

```bash
curl -fsSL -o docker-compose.production.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.production.yml
curl -fsSL -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.production.example
```

Set `.env`:

```bash
LAGO_DOMAIN=billing.example.com
LAGO_ACME_EMAIL=infra@example.com
PORTAINER_USER=lago
PORTAINER_PASSWORD=change-me
```

Run:

```bash
docker compose -f docker-compose.production.yml up -d --profile all
```

## VPS and reverse-proxy checklist

1. Point DNS to your VPS (`A`/`AAAA` record for `LAGO_DOMAIN`)
2. Open inbound ports `80` and `443`
3. Use `Light` or `Production` mode (both ship with Traefik)
4. Set `LAGO_DOMAIN` and `LAGO_ACME_EMAIL` in `.env`
5. Start with `--profile all` (or selective profiles below)
6. Verify `https://<LAGO_DOMAIN>` and `https://<LAGO_DOMAIN>/api`

## Configuration

### Profiles

The compose files support these profiles:

- `all`: enable all services
- `all-no-pg`: disable PostgreSQL (use external PostgreSQL)
- `all-no-redis`: disable Redis (use external Redis)
- `all-no-db`: disable PostgreSQL and Redis
- `all-no-keys`: disable RSA key generation

Examples:

```bash
# Without PostgreSQL
docker compose -f docker-compose.light.yml up -d --profile all-no-pg

# Without Redis
docker compose -f docker-compose.light.yml up -d --profile all-no-redis

# Without PostgreSQL and Redis
docker compose -f docker-compose.light.yml up -d --profile all-no-db

# Without generated RSA key
docker compose -f docker-compose.light.yml up -d --profile all-no-keys
```

### External PostgreSQL

Set:

- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `POSTGRES_SCHEMA` (optional)

Then run with `--profile all-no-pg`.

### External Redis

Set:

- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_PASSWORD` (optional)

Then run with `--profile all-no-redis`.

### RSA key management

By default, compose generates an RSA key pair used for JWT signing. To provide your own key:

1. Remove the `lago_rsa_data` volume
2. Generate a key with `openssl genrsa 2048 | openssl base64 -A`
3. Set `LAGO_RSA_PRIVATE_KEY`
4. Start with `--profile all-no-keys`

All backend services must share the same private key.

### Apply `.env` changes safely

When changing public URL variables (`LAGO_DOMAIN`, `LAGO_API_URL`, `LAGO_FRONT_URL`, `API_URL`), recreate the impacted services so runtime config is regenerated:

```bash
docker compose down
docker compose up -d --profile all
```

## Monitoring

For production deployments, set up Sidekiq monitoring. See [Monitoring documentation](../docs/monitoring.md) for:

- Prometheus metrics and available metrics
- Recommended alerting rules
- Grafana dashboard recommendations
