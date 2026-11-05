# Lago Docker Image

This is the official one docker image for Lago.

This docker image is designed for testing and staging environments only. It is not recommended for production use due to its simplified architecture and resource constraints. For production deployments, please refer to our deployment guides in the `deploy` folder or use our [helm chart](https://github.com/getlago/lago-helm-charts) for a more robust and scalable setup.

## Features

This docker image embed everything to run Lago with just one command line to ease the deployment.
Here are the services that are running into the container :
- PostgreSQL 18 (with pg_partman)
- Valkey (Redis-compatible)
- Lago UI
- Lago API
- Lago Worker
- Lago Clock

The image is built on hardened [Wolfi](https://github.com/wolfi-dev) bases from
[lago-packages](https://github.com/getlago/lago-packages). Every process runs as
the nonroot user (uid 65532). The image has no package manager.

## Get Started

```bash
docker run -d --name lago --stop-timeout 40 -v lago_data:/data -p 80:80 -p 3000:3000 getlago/lago:latest
```

`--stop-timeout 40` gives running background jobs time to go back to the queue when the
container stops. With the Docker default of 10 s, Docker kills every process, Postgres included.

## PDF Generation

PDF generation uses [Gotenberg](https://github.com/gotenberg/gotenberg), which runs in its own container.
Start it next to Lago:

```bash
docker run -d --name lago-pdf -p 3001:3000 ghcr.io/getlago/lago-gotenberg:8.39
docker run -d --name lago --stop-timeout 40 --add-host=host.docker.internal:host-gateway \
  -v lago_data:/data -p 80:80 -p 3000:3000 getlago/lago:latest
```

Lago reaches it at `LAGO_PDF_URL`, which defaults to `http://host.docker.internal:3001`.
Docker Desktop resolves `host.docker.internal` without `--add-host`.

Earlier images started `lago-pdf` themselves through a mounted `/var/run/docker.sock`.
This image does not: the socket gives root access to the host.

## Using External Services

You can use external services for the database and Redis instance.
Here are the env var you should pass to the container to use them :

| Env Var | Description | Default |
|---------|-------------|---------|
| DATABASE_URL | The URL of the database | postgres://lago:lago@localhost:5432/lago |
| REDIS_URL | The URL of the Redis instance | redis://localhost:6379/0 |


## Storage

The container is using a volume to store the data, you can mount it to your host to keep the data safe.
You can find many folders for each services in the `/data` folder:

| Path | Content |
|------|---------|
| `/data/.env` | Generated secrets and settings |
| `/data/postgresql` | PostgreSQL cluster |
| `/data/valkey` | Valkey append-only file (Sidekiq jobs) |
| `/data/storage` | Uploaded and generated files (invoice PDFs, exports) |
| `/data/*.log` | Database setup, PostgreSQL and Valkey logs |

### Upgrading from an image older than the Wolfi one

Earlier images ran as root and kept the PostgreSQL and Redis data in the container, not in `/data`.
Their `/data` volume holds only `.env` and `db.log`, and root owns it.
Give the volume to the nonroot user once, then start the new image:

```bash
docker run --rm -u 0 -v lago_data:/data --entrypoint chown getlago/lago:latest -R 65532:65532 /data
```

A bind mount works the same way: `chown -R 65532:65532 <host directory>` on the host.


## SSL

SSL is disabled by default in this development/staging image. To enable SSL support when using a proxy or load balancer:

For new installations:
- Add the environment variable `LAGO_DISABLE_SSL=false` when running the container
  ```bash
  docker run -e LAGO_DISABLE_SSL=false ...
  ```

For existing installations:
- Navigate to your `/data` volume
- Edit the `.env` file to change `LAGO_DISABLE_SSL=true` to `LAGO_DISABLE_SSL=false`

:warning: Note that this only enables SSL support - you must still configure SSL certificates and termination through your reverse proxy or load balancer.

## Logs

Database Logs (creation, migration) are stored in the `/data/db.log` file.
PostgreSQL and Valkey write to `/data/postgresql.log` and `/data/valkey.log`.
Applicative logs are streamed to the standard output.

## Contributing

This docker image is a work in progress.
Feel free to open issues or PRs to improve it or ask for new features.
