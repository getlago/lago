# BFP Lago local sem Docker

Este guia registra o setup inicial do `etusdigital/bfp-lago` como monorepo privado: o codigo do Lago API e do Lago Front fica versionado diretamente dentro deste repositorio, sem submodulos.

## 1. Validar o repo principal

```powershell
cd C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago

git config --global --add safe.directory C:/Users/ETUS-0711/Documents/PROJETOS/etus-projects/bfp-lago
git config --global core.longpaths true
git config core.longpaths true

git remote -v
git remote add upstream https://github.com/getlago/lago.git
git remote set-url --push upstream DISABLED
```

Esperado:

```text
origin   https://github.com/etusdigital/bfp-lago.git
upstream https://github.com/getlago/lago.git
```

Use `origin` para push e `upstream` apenas como referencia do Lago original.

## 2. Como o codigo foi absorvido

O Lago original usa submodulos:

- `api` vinha de `getlago/lago-api`
- `front` vinha de `getlago/lago-front`

Neste repo, os submodulos foram removidos e as pastas `api/` e `front/` passaram a ser codigo normal do `bfp-lago`.

Versoes de origem absorvidas:

- `api`: `32efd35931cca340050c2623d811b14e75d78de9`
- `front`: `19fa76109a48fbd30e693651135b9f9cb65341cb`

Isso evita depender de forks separados como `bfp-lago-api` e `bfp-lago-front`.

## 3. Pre-requisitos sem Docker

Instale na maquina:

- Ruby `4.0.2`
- Bundler `4.0.4`
- Node `24.18.0`
- pnpm `10.34.4` ou compativel
- PostgreSQL local
- Redis local

Neste checkout, ja existe PostgreSQL 16, mas ainda faltam Ruby e Redis no PATH.
O Node bundled do Codex esta em `24.14.0`; para reproduzir exatamente o lockfile do front, prefira `24.18.0`.

## 4. Variaveis locais

Crie arquivos ignorados pelo Git:

- `api/.env`
- `front/.env`
- `api/config/keys/private.pem`

Neste workspace eles ja foram criados com valores locais para:

- API em `http://localhost:3000`
- Front em `http://localhost:5173`
- Postgres em `localhost:5432`
- Redis em `localhost:6379`
- ClickHouse e PDF desabilitados no primeiro boot

Importante: para ClickHouse, deixe `LAGO_CLICKHOUSE_ENABLED` vazio. Em alguns pontos do codigo, qualquer valor presente, inclusive `false`, pode ser tratado como habilitado.

## 5. Banco local

Crie usuario e banco no PostgreSQL:

```powershell
psql -U postgres
```

```sql
CREATE USER lago WITH PASSWORD 'changeme';
ALTER USER lago CREATEDB;
CREATE DATABASE lago OWNER lago;
```

Nesta maquina, `localhost:5432` esta respondendo, mas a autenticacao com `lago/changeme` falhou. Se o usuario `lago` ja existir com outra senha, ajuste com:

```sql
ALTER USER lago WITH PASSWORD 'changeme';
ALTER USER lago CREATEDB;
```

## 6. Instalar dependencias e subir API

```powershell
cd C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago\api
gem install bundler -v 4.0.4
bundle install
bundle exec rails db:prepare
bundle exec rails server -p 3000
```

Em outro terminal, suba o worker quando Redis estiver rodando:

```powershell
cd C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago\api
bundle exec sidekiq
```

## 7. Instalar dependencias e subir front

```powershell
cd C:\Users\ETUS-0711\Documents\PROJETOS\etus-projects\bfp-lago\front
pnpm install
pnpm dev --host 127.0.0.1 --port 5173
```

Abra `http://localhost:5173`.

Credenciais locais criadas pelo seed:

- email: `admin@bfp.local`
- senha: `password`
- API key: `lago_key_bfp_local`

## 8. Atualizar a partir do Lago no futuro

Como `api/` e `front/` agora sao codigo comum dentro do `bfp-lago`, atualizar a partir do Lago original deve ser uma operacao manual e revisada:

1. Consulte o upstream principal:

```powershell
git fetch upstream
git log --oneline main..upstream/main
```

2. Para atualizar API ou Front, compare contra os repos originais do Lago em um clone temporario ou em uma branch separada:

```powershell
git clone https://github.com/getlago/lago-api.git C:\tmp\lago-api-upstream
git clone https://github.com/getlago/lago-front.git C:\tmp\lago-front-upstream
```

3. Traga apenas as mudancas desejadas para `api/` e `front/`, rode testes e commite no `bfp-lago`.

Evite rodar `git submodule update`, porque este repo nao usa mais submodulos.
