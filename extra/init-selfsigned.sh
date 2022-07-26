#!/bin/bash

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./extra/ssl/nginx-selfsigned.key -out ./extra/ssl/nginx-selfsigned.crt
sudo openssl dhparam -out ./extra/ssl/dhparam.pem 2048
