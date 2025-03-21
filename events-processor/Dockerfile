FROM rust:1.82 AS rust-build

RUN git clone https://github.com/getlago/lago-expression/
WORKDIR /lago-expression/expression-go
RUN git checkout v0.1.4 && cargo build --release

FROM golang:1.24 AS go-build

WORKDIR /app

COPY . /app/

RUN go mod download
COPY --from=rust-build /lago-expression/target/release/libexpression_go.so /usr/lib/libexpression_go.so
RUN go build -o event_processors .

FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates

WORKDIR /app
COPY --from=rust-build /lago-expression/target/release/libexpression_go.so /usr/lib/libexpression_go.so
COPY --from=go-build /app/event_processors /app/event_processors
ENTRYPOINT ["./event_processors"]
