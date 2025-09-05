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

2. Run the following command to start the project:

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
curl -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.light.example
```

2. Replace the .env values with yours

```bash
LAGO_DOMAIN=domain.tld
LAGO_ACME_EMAIL=email@domain.tld
```

3. Run the following command to start the project

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
curl -o .env https://raw.githubusercontent.com/getlago/lago/main/deploy/.env.production.example
```

2. Replace the .env values with yours

```bash
LAGO_DOMAIN=domain.tld
LAGO_ACME_EMAIL=email@domain.tld
PORTAINER_USER=lago
PORTAINER_PASSWORD=changeme
```

3. Run the following command to start the project

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
