# Lago

## Requirements

- Git
- Docker
  - [Docker for Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
  - [Docker Desktop for MacOS](https://www.docker.com/products/docker-desktop)
- Homebrew (macOS only)
  ```shell
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- OpenSSL
  ```shell
  # Ubuntu/Debian
  sudo apt update
  sudo apt install openssl

  # MAC OS
  brew install openssl
  ```

## Local Environment Setup

- First of all, you need to clone the Lago repo on your machine, since we're using Git submodules, here is the good command to do it
```shell
git clone --recurse-submodules git@github.com:getlago/lago.git
cd lago

# If you're not using bash, replace .bashrc with your shell rc, ei: ~/.zshrc
echo "export LAGO_PATH=${PWD}" >> ~/.bashrc
echo 'alias lago="docker-compose -f $LAGO_PATH/docker-compose.dev.yml"' >> ~/.bashrc
source ~/.bashrc
```

- Install `mkcert` and generate some certs for TLS usage
```shell
brew install mkcert nss
mkcert -install
cd $LAGO_PATH/traefik
mkdir certs
cd certs
mkcert -cert-file lago.dev.pem -key-file lago.dev-key.pem lago.dev "*.lago.dev"
```

- Add all custom domains to your `/etc/hosts` file
```
127.0.0.1 traefik.lago.dev
127.0.0.1 api.lago.dev
127.0.0.1 app.lago.dev
```

- Setup API

```shell
cp ./api/.env.dist ./api/.env
touch ./api/config/master.key
```

Populate the `./api/config/master.key` file with the value from [1Password](https://start.1password.com/open/i?a=CV2K6WPYLZBXXGIKIUYUJOA3Z4&v=4k453pfxong4lipf3oookha7ei&i=kc2v2trpahmnzcl5k3krdl2z3y&h=my.1password.com).

## Local Environment Commands

- Start your local environment
```shell
lago up -d db redis traefik
lago up front api
```

- Start enjoying your local Lago at https://app.lago.dev

## Update your local copie of the code

```shell
git pull --recurse-submodules
```
