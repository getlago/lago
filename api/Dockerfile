ARG PDFCPU_VERSION=0.11.1
ARG GO_VERSION=1.25.8

FROM golang:${GO_VERSION} AS pdfcpu-build

ARG PDFCPU_VERSION

RUN go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@v${PDFCPU_VERSION}

FROM ruby:4.0.2-slim AS build

ARG BUNDLE_WITH

WORKDIR /app

RUN apt update && apt upgrade -y
RUN apt install nodejs curl build-essential git pkg-config libpq-dev libclang-dev postgresql-client curl libyaml-dev -y && \
  curl https://sh.rustup.rs -sSf | bash -s -- -y

COPY ./Gemfile /app/Gemfile
COPY ./Gemfile.lock /app/Gemfile.lock

ENV BUNDLER_VERSION='4.0.4'
ENV PATH="$PATH:/root/.cargo/bin/"
RUN gem install bundler --no-document -v '4.0.4'

ENV BUNDLE_WITH=${BUNDLE_WITH:-}
ENV BUNDLE_WITHOUT="development test"
RUN --mount=type=secret,id=BUNDLE_GEMS__CONTRIBSYS__COM,env=BUNDLE_GEMS__CONTRIBSYS__COM \
  bundle config set build.nokogiri --use-system-libraries &&\
  bundle install --jobs=3 --retry=3

FROM ruby:4.0.2-slim

ARG BUNDLE_WITH

RUN apt update && apt upgrade -y
RUN apt install git libpq-dev curl postgresql-client libjemalloc2 -y

ENV LD_PRELOAD=libjemalloc.so.2

ARG SEGMENT_WRITE_KEY
ARG GOCARDLESS_CLIENT_ID
ARG GOCARDLESS_CLIENT_SECRET

ENV SEGMENT_WRITE_KEY=$SEGMENT_WRITE_KEY
ENV GOCARDLESS_CLIENT_ID=$GOCARDLESS_CLIENT_ID
ENV GOCARDLESS_CLIENT_SECRET=$GOCARDLESS_CLIENT_SECRET

ENV BUNDLE_WITH=${BUNDLE_WITH:-}
ENV BUNDLE_WITHOUT="development test"

COPY --from=build /usr/local/bundle/ /usr/local/bundle
COPY --from=pdfcpu-build /go/bin/pdfcpu /usr/local/bin/pdfcpu
WORKDIR /app
COPY . .

CMD ["./scripts/start.sh"]
