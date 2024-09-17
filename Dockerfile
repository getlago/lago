ARG NODE_VERSION=20
ARG RUBY_VERSION=3.3.4

# Front Build
FROM node:$NODE_VERSION-alpine as front_build

WORKDIR /app

COPY ./front/ .

RUN apk add python3 build-base
RUN yarn && yarn build && npm prune --omit=dev

# # API Build
FROM ruby:$RUBY_VERSION-slim as api_build

WORKDIR /app

COPY ./api/Gemfile ./Gemfile
COPY ./api/Gemfile.lock ./Gemfile.lock

RUN apt update -qq && apt install build-essential git pkg-config libpq-dev curl -y
ENV BUNDLER_VERSION='2.5.5'
ENV RAILS_ENV=production
RUN gem install bundler --no-document -v '2.5.5'
RUN bundle config build.nokogiri --use-system-libraries &&\
    bundle install --jobs=3 --retry=3 --without development test

# Final Image
FROM ruby:$RUBY_VERSION-slim
ARG S6_OVERLAY_VERSION=3.2.0.0

WORKDIR /app

RUN apt-get update && apt-get install -y nginx xz-utils
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

COPY docker/rootfs /
COPY ./front/nginx/nginx.conf /etc/nginx/sites-enabled/default

COPY --from=front_build /app/dist /usr/share/nginx/html
COPY --from=api_build /usr/local/bundle/ /usr/local/bundle

COPY ./front/.env.sh ./front/.env.sh
COPY ./api ./api

RUN bash -c ./front/.env.sh

ENV RAILS_ENV=production

EXPOSE 80
EXPOSE 3000

ENTRYPOINT ["/init"]
