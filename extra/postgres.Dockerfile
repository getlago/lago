FROM postgres:15.0-alpine

ENV PARTMAN_VERSION="v5.4.0"

RUN apk add --no-cache --virtual .fetch-deps wget gcc make musl-dev postgresql-dev

RUN wget "https://github.com/pgpartman/pg_partman/archive/refs/tags/${PARTMAN_VERSION}.tar.gz" \
  # Create the source directory
  && mkdir -p /usr/src/pg_partman \
  # Extract the archive into the source directory
  && tar \
  --extract \
  --file ${PARTMAN_VERSION}.tar.gz \
  --directory /usr/src/pg_partman \
  --strip-components 1 \
  # Remove the archive
  && rm ${PARTMAN_VERSION}.tar.gz \
  # Move into the the source directory and build
  && cd /usr/src/pg_partman \
  && make \
  && make install \
  # Cleanup the source and build dependencies
  && rm -rf /usr/src/pg_partman \
  && apk del .fetch-deps
