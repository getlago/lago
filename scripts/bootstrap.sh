#! /bin/sh

apt update
apt install -y git curl
curl -sL https://deb.nodesource.com/setup_20.x | sh -
apt update
apt install nodejs npm
