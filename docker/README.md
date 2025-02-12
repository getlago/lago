# Lago Docker Image

This is the official one docker image for Lago.
We do not recommend to use it in production for heavy usage, please check the `docker-compose` file in the root of the repository
or our [helm chart](https://github.com/getlago/lago-helm-charts) for a more robust deployment.

## Features

This docker image embed everything to run Lago with just one command line to ease the deployment.
Here are the services that are running into the container :
- PostgreSQL
- Redis
- Lago UI
- Lago API
- Lago Worker
- Lago Clock

## Get Started

```bash
docker run -d --name lago-p 80:80 -p 3000:3000 getlago/lago:latest
```

## Storage

The container is using a volume to store the data, you can mount it to your host to keep the data safe.
You can find many folders for each services in the `/data` folder.

## Logs

Database Logs (creation, migration) are stored in the `/data/db.log` file.
Applicative logs are streamed to the standard output.

## Contributing

This docker image is a work in progress, this does not provide a lot of features yet (ei: external database configuration).
Feel free to open issues or PRs to improve it or ask for new features.
