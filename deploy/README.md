# Lago Deploy

This repository contains the necessary files to deploy the Lago project.

## Docker Compose Local

To deploy the project locally, you need to have Docker and Docker Compose installed on your machine.
This configuration can be used for small production usages but it's not recommended for large scale deployments.

### Get Started

1. Get the docker compose file

```bash
curl -o docker-compose.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.local.yml
```

2. Generate the secrets. If this install already has data, read [Secrets](#secrets) first: new encryption keys make that data unreadable.

```bash
touch .env
# Add a final newline if the file has none: the lines below must not join the last line.
[ -n "$(tail -c1 .env)" ] && echo >> .env
grep -q '^SECRET_KEY_BASE=.' .env || echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
for key in LAGO_ENCRYPTION_PRIMARY_KEY LAGO_ENCRYPTION_DETERMINISTIC_KEY LAGO_ENCRYPTION_KEY_DERIVATION_SALT; do
  grep -q "^${key}=." .env || echo "${key}=$(openssl rand -hex 32)" >> .env
done
```

3. Run the following command to start the project:

```bash
docker compose up --profile all

# If you want to run it in the background
docker compose up -d --profile all
```

## Docker Compose Light

This configuration provide Traefik as a reverse proxy to ease your deployment.
It supports SSL with Let's Encrypt. :warning: You need a valid domain (with at least one A or AAA record)!

1. Get the docker compose file

```bash
curl -o docker-compose.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.light.yml
# Keep an existing .env: it holds the secrets of this install
[ -f .env ] || curl -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.light.example
```

2. Replace the .env values with yours

```bash
LAGO_DOMAIN=domain.tld
LAGO_ACME_EMAIL=email@domain.tld
```

3. Generate the secrets. If this install already has data, read [Secrets](#secrets) first: new encryption keys make that data unreadable.

```bash
touch .env
# Add a final newline if the file has none: the lines below must not join the last line.
[ -n "$(tail -c1 .env)" ] && echo >> .env
grep -q '^SECRET_KEY_BASE=.' .env || echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
for key in LAGO_ENCRYPTION_PRIMARY_KEY LAGO_ENCRYPTION_DETERMINISTIC_KEY LAGO_ENCRYPTION_KEY_DERIVATION_SALT; do
  grep -q "^${key}=." .env || echo "${key}=$(openssl rand -hex 32)" >> .env
done
```

4. Run the following command to start the project

```bash
docker compose up --profile all

# If you want to run it in the background
docker compose up -d --profile all
```

## Docker Compose Production

This configuration provide Traefik as a reverse proxy to ease your deployment.
It supports SSL wth Let's Encrypt. :warning: You need a valid domain (with at least one A or AAA record)!
It also adds multiple services that will help your to handle more load.
Portainer is also packed to help you scale services and manage your Lago stack.

```bash
curl -o docker-compose.yml https://raw.githubusercontent.com/getlago/lago/main/deploy/docker-compose.production.yml
# Keep an existing .env: it holds the secrets of this install
[ -f .env ] || curl -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.production.example
```

2. Replace the .env values with yours

```bash
LAGO_DOMAIN=domain.tld
LAGO_ACME_EMAIL=email@domain.tld
PORTAINER_USER=lago
PORTAINER_PASSWORD=changeme
```

3. Generate the secrets. If this install already has data, read [Secrets](#secrets) first: new encryption keys make that data unreadable.

```bash
touch .env
# Add a final newline if the file has none: the lines below must not join the last line.
[ -n "$(tail -c1 .env)" ] && echo >> .env
grep -q '^SECRET_KEY_BASE=.' .env || echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
for key in LAGO_ENCRYPTION_PRIMARY_KEY LAGO_ENCRYPTION_DETERMINISTIC_KEY LAGO_ENCRYPTION_KEY_DERIVATION_SALT; do
  grep -q "^${key}=." .env || echo "${key}=$(openssl rand -hex 32)" >> .env
done
```

4. Run the following command to start the project

```bash
docker compose up --profile all

# If you want to run it in the background
docker compose up -d --profile all
```


## Configuration

### Profiles

The docker compose file contains multiple profiles to enable or disable some services.
Here are the available profiles:
- `all`: Enable all services
- `all-no-pg`: Disable the PostgreSQL service
- `all-no-redis`: Disable the Redis service
- `all-no-keys`: Disable the RSA keys generation service

This allow you to start only the service you want to use, please see the following sections for more information.

```bash
# Start all services
docker compose up --profile all

# Start without PostgreSQL
docker compose up --profile all-no-pg

# Start without Redis
docker compose up --profile all-no-redis

# Start without PostgreSQL and Redis
docker compose up --profile all-no-db

# Start without RSA keys generation
docker compose up --profile all-no-keys

# Start without PostgreSQL, Redis and RSA keys generation
docker compose up
```

### PostgreSQL

It is possible to disable the usage of the PostgreSQL database to use an external database instance.

1. Set those environment variables:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_SCHEMA` optional

2. Run the following command to start the project without PostgreSQL:

```bash
docker compose up --profile all-no-pg
```

### Redis

It is possible to disable the usage of the Redis database to use an external Redis instance.

1. Set those environment variables:

- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_PASSWORD` optional

2. Run the following command to start the project without Redis:

```bash
docker compose up --profile all-no-redis
```

### RSA Keys

Those docker compose file generates an RSA Keys pair for the JWT tokens generation.
You can find the keys in the `lago_rsa_data` volume or in the `/app/config/keys` directory in the backends containers.
If you do not want to use those keys:
- Remove the `lago_rsa_data` volume
- Generate your own key using `openssl genrsa 2048 | openssl base64 -A`
- Export this generated key to the `LAGO_RSA_PRIVATE_KEY` env var.
- Run the following command to start the project without the RSA keys generation:

```bash
docker compose up --profile all-no-keys
```

*All BE Services use the same RSA key, they will exit immediately if no key is provided.*

### Secrets

The backend services need these secrets. The compose files have no default for them, and they stop with an error if one is missing.

| Variable | Use | If you change it |
|---|---|---|
| `SECRET_KEY_BASE` | Signs sessions, cookies and signed URLs | Users log in again. Safe to rotate. |
| `LAGO_ENCRYPTION_PRIMARY_KEY` | Encrypts sensitive columns (for example integration and payment provider credentials, webhook signing keys) | The data encrypted with the old key becomes unreadable |
| `LAGO_ENCRYPTION_DETERMINISTIC_KEY` | Reserved for deterministic encryption. No column uses it today | Nothing today |
| `LAGO_ENCRYPTION_KEY_DERIVATION_SALT` | Derives the encryption keys | The encrypted data becomes unreadable |

`deploy.sh` and the commands in the sections above generate each secret once and keep it in `.env`. Keep a backup of `.env`: you cannot recover encrypted data without it.

#### Upgrade an install that used the old defaults

Before this change, the compose files used public placeholder values when a secret was not set. The new compose files stop every `docker compose` command (also `down`, `ps` and `logs`) until the secrets are set. If your install ran with the old values, do these steps before you use the new compose file:

1. Set `SECRET_KEY_BASE` to a new value: `openssl rand -hex 64`. Anyone can read the old value, so replace it now.
2. Keep the encryption values that your data already uses. If you never set them, your install used these exact strings. They are not placeholders: copy them into `.env` as they are.

   ```bash
   LAGO_ENCRYPTION_PRIMARY_KEY=your-encryption-primary-key
   LAGO_ENCRYPTION_DETERMINISTIC_KEY=your-encryption-deterministic-key
   LAGO_ENCRYPTION_KEY_DERIVATION_SALT=your-encryption-derivation-salt
   ```

   Do not generate new encryption keys for an install that has data. Lago cannot rotate the encryption keys yet: it does not read previous keys, and it has no task to re-encrypt the data. Until it can, the encrypted credentials of such an install stay protected only by these public values.

## Monitoring

For production deployments, we recommend setting up monitoring for Sidekiq workers. See the [Monitoring documentation](../docs/monitoring.md) for:
- Prometheus metrics endpoints and available metrics
- Recommended alerting rules
- Grafana dashboard recommendations
