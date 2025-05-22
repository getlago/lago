# Lago Docker Image

This is the official one docker image for Lago.

This docker image is designed for testing and staging environments only. It is not recommended for production use due to its simplified architecture and resource constraints. For production deployments, please refer to our deployment guides in the `deploy` folder or use our [helm chart](https://github.com/getlago/lago-helm-charts) for a more robust and scalable setup.

## Features

This docker image embed everything to run Lago with just one command line to ease the deployment.
Here are the services that are running into the container :
- PostgreSQL
- Redis
- Lago UI
- Lago API
- Lago Worker
- Lago Clock
- PDF Service (optional)

## Get Started

```bash
docker run -d --name lago -p 80:80 -p 3000:3000 getlago/lago:latest
```

PDF generation is disabled by default. We use [Gotenberg](https://github.com/gotenberg/gotenberg), which is only available as a Docker image. To enable PDF generation, use the following command:

```bash
docker run -d --name lago -v /var/run/docker.sock:/var/run/docker.sock -p 80:80 -p 3000:3000 getlago/lago:latest
```

You will see an other docker container named `lago-pdf` running.

## Using External Services

You can use external services for the database and Redis instance.
Here are the env var you should pass to the container to use them :

| Env Var | Description | Default |
|---------|-------------|---------|
| DATABASE_URL | The URL of the database | postgres://lago:lago@localhost:5432/lago |
| REDIS_URL | The URL of the Redis instance | redis://localhost:6379/0 |


## Storage

The container is using a volume to store the data, you can mount it to your host to keep the data safe.
You can find many folders for each services in the `/data` folder.


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
Applicative logs are streamed to the standard output.

## Contributing

This docker image is a work in progress.
Feel free to open issues or PRs to improve it or ask for new features.
