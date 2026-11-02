#!/bin/bash

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./extra/ssl/nginx-selfsigned.key -out ./extra/ssl/nginx-selfsigned.crt
# The front container runs nginx as uid 65532, so it must be able to read the
# key. No DH parameters: the image's OpenSSL cannot load them, and nginx
# uses ECDHE without them.
sudo chown 65532:65532 ./extra/ssl/nginx-selfsigned.key ./extra/ssl/nginx-selfsigned.crt
sudo chmod 600 ./extra/ssl/nginx-selfsigned.key
