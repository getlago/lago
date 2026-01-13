# Lago Deploy

This repository contains the necessary files to deploy the Lago project using Docker Compose.

## Quick Start

Run the interactive deploy script:

```bash
curl -s https://deploy.getlago.com/deploy.sh | bash
```

Or manually download and configure:

```bash
curl -o docker-compose.yml https://deploy.getlago.com/docker-compose.yml
curl -o .env https://deploy.getlago.com/.env.example
```

## Deploy Script Options

The `deploy.sh` script supports several flags for automation and testing:

### Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be executed without running |
| `--non-interactive` or `-y` | Use environment variables instead of prompts |
| `--skip-download` | Use local docker-compose.yml instead of downloading |
| `--help` | Show usage information |

### Environment Variables for Non-Interactive Mode

| Variable | Description |
|----------|-------------|
| `LAGO_DEPLOY_CHOICE` | Deployment choice: 1=Quickstart, 2=Local, 3=Light, 4=Production |
| `LAGO_EXTERNAL_PG` | Use external PostgreSQL: `true`/`false` (default: `false`) |
| `LAGO_EXTERNAL_REDIS` | Use external Redis: `true`/`false` (default: `false`) |
| `LAGO_DOMAIN` | Domain for Light/Production deployments |
| `LAGO_ACME_EMAIL` | Email for SSL certificates |

### Examples

```bash
# Interactive deployment (default)
./deploy.sh

# Non-interactive local deployment
LAGO_DEPLOY_CHOICE=2 ./deploy.sh --non-interactive

# Dry-run to see what would happen
LAGO_DEPLOY_CHOICE=3 LAGO_DOMAIN=lago.example.com LAGO_ACME_EMAIL=admin@example.com \
  ./deploy.sh --non-interactive --dry-run

# Test with local docker-compose.yml (skip download)
LAGO_DEPLOY_CHOICE=2 ./deploy.sh --non-interactive --skip-download

# Production with external PostgreSQL
LAGO_DEPLOY_CHOICE=4 LAGO_DOMAIN=lago.example.com LAGO_ACME_EMAIL=admin@example.com \
  LAGO_EXTERNAL_PG=true POSTGRES_HOST=db.example.com POSTGRES_USER=lago \
  POSTGRES_PASSWORD=secret POSTGRES_PORT=5432 POSTGRES_DB=lago \
  ./deploy.sh --non-interactive
```

## Deployment Profiles

The docker-compose.yml uses profiles to support different deployment scenarios:

### Deployment Types (choose one)

| Profile | Description |
|---------|-------------|
| `local` | Local development without SSL, exposes ports directly |
| `light` | Small production with Traefik reverse proxy and SSL |
| `production` | Full production with Traefik, optimized for scale |

### Infrastructure (additive)

| Profile | Description |
|---------|-------------|
| `db` | Include local PostgreSQL database |
| `redis` | Include local Redis instance |

## Usage Examples

### Local Development

Full local setup with local database and Redis:

```bash
docker compose --profile local --profile db --profile redis up -d
```

Access Lago at:
- Frontend: http://localhost
- API: http://localhost:3000

### Light Production

Small production deployment with SSL (requires valid domain):

```bash
# With local DB and Redis
docker compose --profile light --profile db --profile redis up -d

# With external DB, local Redis
docker compose --profile light --profile redis up -d

# With all external services
docker compose --profile light up -d
```

### Full Production

Optimized for high load with specialized workers:

```bash
# With local infrastructure
docker compose --profile production --profile db --profile redis up -d

# With external database
docker compose --profile production --profile redis up -d
```

## Configuration

### Required Environment Variables

#### For Light/Production profiles

| Variable | Description |
|----------|-------------|
| `LAGO_DOMAIN` | Your domain (e.g., `lago.example.com`) |
| `LAGO_ACME_EMAIL` | Email for Let's Encrypt certificates |

### External PostgreSQL

To use an external PostgreSQL database, omit the `db` profile and set:

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_HOST` | Yes | Database host |
| `POSTGRES_PORT` | Yes | Database port (default: 5432) |
| `POSTGRES_USER` | Yes | Database user |
| `POSTGRES_PASSWORD` | Yes | Database password |
| `POSTGRES_DB` | Yes | Database name |
| `POSTGRES_SCHEMA` | No | Schema name (default: public) |

```bash
docker compose --profile light --profile redis up -d
```

### External Redis

To use an external Redis instance, omit the `redis` profile and set:

| Variable | Required | Description |
|----------|----------|-------------|
| `REDIS_HOST` | Yes | Redis host |
| `REDIS_PORT` | Yes | Redis port (default: 6379) |
| `REDIS_PASSWORD` | No | Redis password |

```bash
docker compose --profile light --profile db up -d
```

### Worker Concurrency

Adjust worker concurrency based on your load:

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKER_CONCURRENCY` | 10 | Main worker concurrency |
| `BILLING_WORKER_CONCURRENCY` | 3 | Billing worker concurrency |
| `PDF_WORKER_CONCURRENCY` | 3 | PDF generation concurrency |
| `WEBHOOK_WORKER_CONCURRENCY` | 5 | Webhook delivery concurrency |
| `CLOCK_WORKER_CONCURRENCY` | 10 | Scheduled job concurrency |
| `EVENTS_WORKER_CONCURRENCY` | 10 | Event processing concurrency |

### Version Management

Set a specific Lago version:

```bash
LAGO_VERSION=v1.28.0 docker compose --profile local --profile db --profile redis up -d
```

### RSA Keys

The docker-compose file generates RSA keys for JWT token generation automatically.
Keys are stored in the `lago_rsa_data` volume.

To use your own keys:
1. Generate a key: `openssl genrsa 2048 | openssl base64 -A`
2. Set the `LAGO_RSA_PRIVATE_KEY` environment variable
3. The key generation service will be skipped if this variable is set

## Services Overview

| Service | Profiles | Description |
|---------|----------|-------------|
| `db` | db | PostgreSQL 15 database |
| `redis` | redis | Redis 7 cache/queue |
| `traefik` | light, production | Reverse proxy with SSL |
| `api` / `api-local` | all | Rails API server |
| `front` / `front-local` | all | React frontend |
| `clock` | all | Scheduled job scheduler |
| `worker` | all | Main background worker |
| `billing-worker` | production | Billing job processor |
| `pdf-worker` | production | PDF generation worker |
| `webhook-worker` | production | Webhook delivery worker |
| `clock-worker` | production | Scheduled job worker |
| `events-worker` | production | Event processing worker |
| `pdf` | all | Gotenberg PDF service |

## Common Operations

```bash
# View logs
docker compose --profile <profile> logs -f

# View specific service logs
docker compose --profile <profile> logs -f api

# Stop all services
docker compose --profile <profile> down

# Stop and remove volumes (WARNING: deletes data)
docker compose --profile <profile> down -v

# Restart a service
docker compose --profile <profile> restart api

# Scale a worker (production only)
docker compose --profile production --profile db --profile redis up -d --scale worker=3
```

## Troubleshooting

### Services not starting

Check that all required environment variables are set:

```bash
docker compose --profile <profile> config
```

### SSL certificate issues

Ensure your domain has a valid A record pointing to your server:

```bash
dig +short A your-domain.com
```

### Database connection issues

Verify PostgreSQL is healthy:

```bash
docker compose --profile db logs db
docker exec lago-db pg_isready -U lago
```

## Testing

The deploy configuration includes a comprehensive test suite that validates all profile combinations and SSL certificate issuance.

### Testing deploy.sh

Use dry-run mode to test the deploy script without making changes:

```bash
# Test local profile
LAGO_DEPLOY_CHOICE=2 ./deploy.sh --non-interactive --skip-download --dry-run

# Test light profile
LAGO_DEPLOY_CHOICE=3 LAGO_DOMAIN=lago.test LAGO_ACME_EMAIL=test@lago.test \
  ./deploy.sh --non-interactive --skip-download --dry-run

# Test production profile
LAGO_DEPLOY_CHOICE=4 LAGO_DOMAIN=lago.test LAGO_ACME_EMAIL=test@lago.test \
  ./deploy.sh --non-interactive --skip-download --dry-run
```

### Running Integration Tests

Use the test runner script:

```bash
cd deploy

# Run all tests
./test/run-tests.sh all

# Run specific tests
./test/run-tests.sh validate     # Validate compose configs
./test/run-tests.sh local        # Test local profile
./test/run-tests.sh light        # Test light profile with SSL
./test/run-tests.sh production   # Test production profile with SSL
```

### Test Infrastructure

Tests use [Pebble](https://github.com/letsencrypt/pebble), Let's Encrypt's test ACME server, to validate SSL certificate issuance without hitting production Let's Encrypt servers.

The test overlay (`docker-compose.test.yml`) adds:
- **Pebble**: Test ACME server that issues certificates
- **Traefik override**: Configured to use Pebble instead of Let's Encrypt

### Running with Act (GitHub Actions locally)

You can run the GitHub Actions workflow locally using [act](https://github.com/nektos/act):

```bash
# Install act (macOS)
brew install act

# Install act (Linux)
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run all jobs
act -j test-local-profile

# Run SSL tests
act -j test-light-profile-ssl
```

### CI/CD

The GitHub Actions workflow (`.github/workflows/deploy-ci.yml`) runs automatically on:
- Push to `main` branch (when `deploy/` files change)
- Pull requests (when `deploy/` files change)
- Manual trigger via workflow_dispatch

Jobs:
1. **validate-config**: Validates docker-compose syntax for all profile combinations
2. **test-local-profile**: Tests local profile startup and health checks
3. **test-light-profile-ssl**: Tests light profile with Pebble SSL validation
4. **test-production-profile-ssl**: Tests production profile with all workers and SSL
