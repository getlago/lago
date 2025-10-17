ARG NODE_VERSION=20
ARG RUBY_VERSION=3.4.7

# Front Build
FROM node:$NODE_VERSION-alpine AS front_build

WORKDIR /app

COPY ./front/ .

RUN apk add python3 build-base && \
  corepack enable && corepack prepare pnpm@latest --activate && \
  rm -rf /app/node_modules && \
  pnpm install && pnpm build && pnpm prune --prod

# API Build
FROM ruby:$RUBY_VERSION-slim AS api_build

ENV BUNDLER_VERSION='2.5.5'
ENV PATH="$PATH:/root/.cargo/bin/"

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && \
  apt-get install nodejs curl build-essential git pkg-config libpq-dev libclang-dev libyaml-dev curl -y && \
  curl https://sh.rustup.rs -sSf | bash -s -- -y

COPY ./api/Gemfile /app/Gemfile
COPY ./api/Gemfile.lock /app/Gemfile.lock

RUN gem install bundler --no-document -v '2.5.5' && \
  gem install foreman && \
  bundle config build.nokogiri --use-system-libraries &&\
  bundle install --jobs=3 --retry=3 --without development test

# Final Image
FROM ruby:$RUBY_VERSION-slim

WORKDIR /app

RUN apt-get update -y && \
  apt-get install curl ca-certificates gnupg -y && \
  curl -fsSL https://postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql-archive-keyring.gpg > /dev/null && \
  echo deb [arch=amd64,arm64,ppc64e1 signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main | tee /etc/ap && \
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
  chmod a+r /etc/apt/keyrings/docker.asc && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install nginx xz-utils git libpq-dev postgresql-17 redis-server docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y && \
  apt-get remove apt-transport-https -y

COPY ./docker/nginx.conf /etc/nginx/sites-enabled/default

COPY --from=front_build /app/dist /app/front
COPY --from=api_build /usr/local/bundle/ /usr/local/bundle

COPY ./front/.env.sh ./front/.env.sh
COPY ./api ./api
COPY ./docker/Procfile ./api/Procfile
COPY ./docker/runner.sh ./runner.sh

EXPOSE 80
EXPOSE 3000
VOLUME /data

ENTRYPOINT ["./runner.sh"]
