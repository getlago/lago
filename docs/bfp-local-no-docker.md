# BFP Lago local sem Docker

Este projeto e um monorepo privado: `api/` e `front/` ficam versionados diretamente em `etusdigital/bfp-lago`, sem submodulos.

O objetivo deste guia e rodar o Lago localmente sem Docker no Windows 11, macOS ou Linux.

## Visao geral

Servicos usados em desenvolvimento:

- API Rails: `http://localhost:3000`
- Front Vite: `http://localhost:5173`
- PostgreSQL: `127.0.0.1:5432`
- Redis: `127.0.0.1:6379`

Versoes esperadas:

- Ruby `4.0.2`
- Bundler `4.0.4`
- Node `24.18.0`
- pnpm `10.34.4`
- PostgreSQL `16`
- Redis compativel

No Windows 11, rode a API Rails dentro do WSL/Ubuntu. Ruby 4 e algumas gems nativas do Lago nao funcionam bem no Windows puro. O front pode rodar no Windows nativo ou no WSL.

## Env local

Arquivos de exemplo:

- `env.example`: catalogo raiz com API + Front
- `api/.env.example`: copie para `api/.env`
- `front/.env.example`: copie para `front/.env`

Criacao inicial:

```powershell
Copy-Item api\.env.example api\.env -Force
Copy-Item front\.env.example front\.env -Force
New-Item -ItemType Directory -Force api\config\keys
openssl genrsa 2048 > api\config\keys\private.pem
```

Depois substitua estes placeholders em `api/.env`:

- `SECRET_KEY_BASE`: gere com `openssl rand -hex 64`
- `LAGO_ENCRYPTION_PRIMARY_KEY`: gere com `openssl rand -hex 32`
- `LAGO_ENCRYPTION_DETERMINISTIC_KEY`: gere com `openssl rand -hex 32`
- `LAGO_ENCRYPTION_KEY_DERIVATION_SALT`: gere com `openssl rand -hex 32`

Para o primeiro boot local, mantenha:

```env
LAGO_DISABLE_PDF_GENERATION=true
LAGO_CLICKHOUSE_ENABLED=
LAGO_CLICKHOUSE_MIGRATIONS_ENABLED=
```

Nao use `LAGO_CLICKHOUSE_ENABLED=false`: partes do codigo testam apenas se a variavel existe.

## Windows 11

### 1. Instalar Ubuntu no WSL

No PowerShell:

```powershell
wsl --install -d Ubuntu
```

Abra o app Ubuntu uma vez e crie o usuario Linux quando ele pedir. Depois confirme:

```powershell
wsl -l -v
```

### 2. Instalar dependencias no Ubuntu

Dentro do Ubuntu:

```bash
sudo apt update
sudo apt install -y build-essential libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libffi-dev libpq-dev redis-server git curl ca-certificates \
  pkg-config libclang-dev clang cmake postgresql postgresql-contrib \
  postgresql-16-partman
```

Instale runtimes com `mise`:

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

mise install ruby@4.0.2 node@24.18.0 rust@stable
mise use -g ruby@4.0.2 node@24.18.0 rust@stable

gem install bundler -v 4.0.4
corepack enable
corepack prepare pnpm@10.34.4 --activate
```

### 3. Preparar banco e gems

No PowerShell, rode o script dentro do WSL:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Users/ETUS-0711/Documents/PROJETOS/etus-projects/bfp-lago && tr -d "\r" < scripts/local/db-prepare-wsl.sh > /tmp/db-prepare-wsl.sh && BFP_LAGO_ROOT="$PWD" bash /tmp/db-prepare-wsl.sh'
```

Se preferir fazer manualmente dentro do Ubuntu:

```bash
cd /mnt/c/Users/ETUS-0711/Documents/PROJETOS/etus-projects/bfp-lago

sudo service postgresql start
sudo service redis-server start

sudo -u postgres psql -c "CREATE USER lago WITH PASSWORD 'changeme' SUPERUSER;" || true
sudo -u postgres psql -c "ALTER USER lago WITH PASSWORD 'changeme' SUPERUSER;"
sudo -u postgres createdb -O lago lago || true

cd api
bundle install
bundle exec rails db:prepare
```

O usuario `lago` fica como `SUPERUSER` somente no ambiente local porque o `structure.sql` do Lago usa extensoes como `pg_partman`.

### 4. Subir API e Sidekiq

Terminal 1:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Users/ETUS-0711/Documents/PROJETOS/etus-projects/bfp-lago && tr -d "\r" < scripts/local/start-api-wsl.sh > /tmp/start-api-wsl.sh && BFP_LAGO_ROOT="$PWD" bash /tmp/start-api-wsl.sh'
```

Terminal 2:

```powershell
wsl -d Ubuntu -- bash -lc 'cd /mnt/c/Users/ETUS-0711/Documents/PROJETOS/etus-projects/bfp-lago && tr -d "\r" < scripts/local/start-sidekiq-wsl.sh > /tmp/start-sidekiq-wsl.sh && BFP_LAGO_ROOT="$PWD" bash /tmp/start-sidekiq-wsl.sh'
```

Valide a API:

```powershell
curl http://localhost:3000/health
```

### 5. Subir front no Windows

Opcao com Node portatil em `.local/node-v24.18.0-win-x64`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\local\start-front.ps1
```

Ou manualmente:

```powershell
$env:Path = "C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago\.local\node-v24.18.0-win-x64;" + $env:Path
cd C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago\front
corepack enable
corepack prepare pnpm@10.34.4 --activate
pnpm install
pnpm dev --host 127.0.0.1 --port 5173
```

Abra `http://localhost:5173`.

## macOS

### 1. Dependencias

```bash
brew install mise postgresql@16 redis pg_partman openssl libyaml libpq

mise install ruby@4.0.2 node@24.18.0 rust@stable
mise use -g ruby@4.0.2 node@24.18.0 rust@stable

gem install bundler -v 4.0.4
corepack enable
corepack prepare pnpm@10.34.4 --activate
```

Se `pg_partman` nao estiver disponivel no Homebrew da maquina, instale a extensao pelo pacote recomendado para a versao local do PostgreSQL ou compile a partir do projeto oficial.

### 2. Banco e Redis

```bash
brew services start postgresql@16
brew services start redis

createuser -s lago || true
createdb -O lago lago || true
psql -d postgres -c "ALTER USER lago WITH PASSWORD 'changeme' SUPERUSER;"
```

### 3. API e front

```bash
cp api/.env.example api/.env
cp front/.env.example front/.env
mkdir -p api/config/keys
openssl genrsa 2048 > api/config/keys/private.pem

cd api
bundle install
bundle exec rails db:prepare
bundle exec rails server -p 3000
```

Em outro terminal:

```bash
cd api
bundle exec sidekiq
```

Em outro terminal:

```bash
cd front
pnpm install
pnpm dev --host 127.0.0.1 --port 5173
```

## Linux

Exemplo Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y build-essential libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libffi-dev libpq-dev redis-server git curl ca-certificates \
  pkg-config libclang-dev clang cmake postgresql postgresql-contrib \
  postgresql-16-partman

curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

mise install ruby@4.0.2 node@24.18.0 rust@stable
mise use -g ruby@4.0.2 node@24.18.0 rust@stable

gem install bundler -v 4.0.4
corepack enable
corepack prepare pnpm@10.34.4 --activate
```

Banco:

```bash
sudo service postgresql start
sudo service redis-server start

sudo -u postgres psql -c "CREATE USER lago WITH PASSWORD 'changeme' SUPERUSER;" || true
sudo -u postgres psql -c "ALTER USER lago WITH PASSWORD 'changeme' SUPERUSER;"
sudo -u postgres createdb -O lago lago || true
```

Aplicacao:

```bash
cp api/.env.example api/.env
cp front/.env.example front/.env
mkdir -p api/config/keys
openssl genrsa 2048 > api/config/keys/private.pem

cd api
bundle install
bundle exec rails db:prepare
bundle exec rails server -p 3000
```

Terminais separados:

```bash
cd api && bundle exec sidekiq
cd front && pnpm install && pnpm dev --host 127.0.0.1 --port 5173
```

## Credenciais locais

Com `LAGO_CREATE_ORG=true`, o seed cria:

- email: `admin@bfp.local`
- senha: `password`
- API key: `lago_key_bfp_local`

## Troubleshooting

### `pg_partman` ou extensoes falhando no `db:prepare`

Confirme que o pacote da extensao esta instalado e que o usuario `lago` e `SUPERUSER` no banco local.

### API tentando conectar em `db`

Confirme que `api/config/database.yml` usa `DATABASE_URL` no ambiente `development` e que `api/.env` existe.

### Front nao acha a API

Confirme `front/.env`:

```env
API_URL=http://localhost:3000
CODEGEN_API=http://localhost:3000/graphql
```

### Windows sem WSL configurado

Rode `wsl --install -d Ubuntu`, abra o app Ubuntu uma vez e crie o usuario Linux. O setup nao termina enquanto esse primeiro usuario nao for criado.

## Atualizar a partir do Lago

```powershell
git fetch upstream
git log --oneline main..upstream/main
```

Traga mudancas de `getlago/lago-api` e `getlago/lago-front` manualmente para `api/` e `front/`. Nao use `git submodule update`.
