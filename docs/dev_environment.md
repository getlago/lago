# Development Environment

Welcome to the Lago development environment setup guide!

This documentation is designed for contributors who want to work on Lago. If you're just looking to try Lago locally, please refer to the [Lago public documentation](https://doc.getlago.com/docs/guide/self-hosting/docker) for a simpler setup.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Git**
- **Docker**
  - [Docker for Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
  - [Docker Desktop for macOS](https://www.docker.com/products/docker-desktop)
- **Homebrew** (macOS only)

  ```shell
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

- **OpenSSL**

  ```shell
  # Ubuntu/Debian
  sudo apt update
  sudo apt install openssl

  # macOS
  brew install openssl
  ```

## Setting Up Your Local Environment

### Clone the Repository

First of all, you need to clone the Lago repo on your machine. Since we're using Git submodules, you need to use the following command:

```shell
git clone --recurse-submodules git@github.com:getlago/lago.git
cd lago
```

### `lago` command

In order to simplify how we work with Docker, we suggest creating a `lago` command that will be available in your terminal.

You'll need to export the `LAGO_PATH` environment variable and add the `lago` alias to your shell rc, e.g. `.bashrc` or `.zshrc`:

- For Bash:

  ```shell
  echo "export LAGO_PATH=${PWD}" >> ~/.bashrc
  echo 'alias lago="docker compose -f $LAGO_PATH/docker-compose.dev.yml"' >> ~/.bashrc
  source ~/.bashrc
  ```

- For Zsh:

  ```shell
  echo "export LAGO_PATH=${PWD}" >> ~/.zshrc
  echo 'alias lago="docker compose -f $LAGO_PATH/docker-compose.dev.yml"' >> ~/.zshrc
  source ~/.zshrc
  ```

- For Fish:

  ```shell
  echo "setenv LAGO_PATH $PWD" >> ~/.config/fish/config.fish
  echo 'alias lago="docker compose -f $LAGO_PATH/docker-compose.dev.yml"' >> ~/.config/fish/config.fish
  source ~/.config/fish/config.fish
  ```

### Traefik

Traefik is used to manage the TLS certificates and the routing to the different services.

To make it work:

1. Install `mkcert` :

    ```shell
    brew install mkcert nss
    ```

2. Generate some certs for TLS usage:

    ```shell
    mkcert -install
    cd $LAGO_PATH/traefik
    mkdir certs
    cd certs
    mkcert -cert-file lago.dev.pem -key-file lago.dev-key.pem lago.dev "*.lago.dev"
    ```

3. Add all custom domains to your `/etc/hosts` file:

    ```shell
    # Lago local domains
    127.0.0.1 traefik.lago.dev
    127.0.0.1 api.lago.dev
    127.0.0.1 app.lago.dev
    127.0.0.1 pdf.lago.dev
    127.0.0.1 license.lago.dev
    127.0.0.1 mail.lago.dev
    127.0.0.1 webhook.lago.dev
    ```

### Configuring the API

```shell
cd $LAGO_PATH
cp ./api/.env.dist ./api/.env
touch ./api/config/master.key
```

## Running the app

Start the dependencies (DB, Redis, Traefik, Mailhog, Clickhouse) via:

```shell
lago up -d --wait db redis traefik mailhog clickhouse webhook
```

Then start the default services (Front, API, API worker, Clock (CRON)):

```shell
lago up front api api-worker api-clock
```

You can now access your local Lago at <https://app.lago.dev>.

Once everything is running fine, you can run the services in detached mode:

```shell
lago up -d --wait front api api-worker api-clock
```

### Arbitrary commands

Since `lago` is an alias for `docker compose`, you can run arbitrary commands using `lago exec <service> <command>`.

For instance, to start the Rails console or run migrations, run:

```shell
lago exec api bundle exec rails console
# or
lago exec api bundle exec rails db:migrate
```

### Environment Variables

Docker services will rely on [`.env.development.default`](../.env.development.default) to find all the necessary env variable. You can override any variable by creating/updating the `.env.development` file.

_Example:_ If you want to disable Clickhouse, you can set `LAGO_CLICKHOUSE_ENABLED=false` in your `.env.development`, which will override the default value set in `.env.development.default`

Note that `.env.development.default` is versioned with Git but `.env.development` is ignored. So make sure to only update `.env.development` when you want to override a variable.

Also keep in mind that the docker `.env` files are not interpolated so make sure all values are static (no `ENV_VAR=${MY_VAR_FROM_SHELL}`).

### Seeding your DB

When launching the API for the first time, the DB will be seeded with some data (organization, user, etc.). See [the seed files](https://github.com/getlago/lago-api/blob/main/db/seeds) for more information.

You can also specify the organization, user, and API key to be created when starting the app by setting the following env variables to your `.env.development` file:

```shell
LAGO_CREATE_ORG=true
LAGO_ORG_USER_EMAIL=your-email@example.com
LAGO_ORG_USER_PASSWORD=password
LAGO_ORG_NAME=Acme
LAGO_ORG_API_KEY=lago_key_1234567890
```

### Dedicated workers and queues

By default, asynchronous jobs are processed by the `api-worker` or `api-clock` services in the queues defined respectively in [`api/config/sidekiq/sidekiq.yml`](https://github.com/getlago/lago-api/blob/main/config/sidekiq/sidekiq.yml) and [`api/config/sidekiq/sidekiq_clock.yml`](https://github.com/getlago/lago-api/blob/main/config/sidekiq/sidekiq_clock.yml).

But on production, we rely on dedicated workers and queues for certain jobs. Whether jobs are pushed to those queues or not is controlled with boolean env variables starting with `SIDEKIQ_` such as `SIDEKIQ_EVENTS`.

You can reproduce this behavior locally by enabling a dedicated queue in `.env.development`, e.g. `SIDEKIQ_EVENTS=true`, and running the associated queue worker:

```shell
lago up -d api-events-worker
```

To get the full list of workers, run:

```shell
lago config --services | grep 'worker'
```

## Testing

Before running tests, you'll need to create the test database:

```shell
lago exec -e LAGO_DISABLE_SCHEMA_DUMP=true -e RAILS_ENV=test api bundle exec rails db:create db:migrate
```

### Running tests automatically

It is possible to run tests automatically when you save a file using [Guard](https://github.com/guard/guard):

```shell
lago exec api bundle exec guard
```

### Running tests manually

It is also possible to run tests manually via RSpec:

```shell
lago exec api bundle exec rspec
lago exec api bundle exec rspec <your_file_spec.rb>
```

## Linting

We use [Rubocop](https://github.com/rubocop/rubocop) to lint the code.

To run the linter, run:

```shell
lago exec api bundle exec rubocop
lago exec api bundle exec rubocop -A # Auto-correct offenses
```

We recommend running the linter automatically when you save a file using your editor "Format on save" feature.

## Development

We rely on Git submodules to manage the [API](https://github.com/getlago/lago-api) and [Front](https://github.com/getlago/lago-front) repositories. Check the [Git submodules documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for more information.

### Working on a submodule

Simply go in the submodule directory and checkout a new branch:

```shell
cd $LAGO_PATH/api
git checkout -b <your_branch_name>
# make your changes
git add .
git commit -m "feat: add your changes"
git push origin <your_branch_name>
```

This will create a new branch in the [`lago-api`](https://github.com/getlago/lago-api) repository and push it to the remote repository.

### Updating a reference

If you want to update a reference to a commit in the submodule, you can do so by checking out the commit within the submodule and committing the changes to the main repository:

```shell
cd $LAGO_PATH/api
git fetch origin main
git checkout <commit_hash>
cd ..
git add api
git commit -m "feat: update api submodule"
git push origin main
```

### Pulling the latest changes

To pull the latest changes from the submodules, run:

```shell
git pull --recurse-submodules
```

### Emails

We rely on [Mailhog](https://github.com/mailhog/MailHog) to test emails locally.

To access the Mailhog web interface, you can use the following URL: <https://mail.lago.dev>.

### Webhooks

We rely on [Webhook tester](https://github.com/tarampampam/webhook-tester) to test webhooks locally.

The seeds create a webhook endpoint with the following URL: <http://webhook/11111111-2222-3333-4444-555555555555>.

Requests sent to this URL will be logged in the Webhook tester web interface: <https://webhook.lago.dev/s/11111111-2222-3333-4444-555555555555>.

## Setup license service

Follow instructions at [https://github.com/getlago/lago-license](https://github.com/getlago/lago-license).
