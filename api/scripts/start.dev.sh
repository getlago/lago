#!/bin/bash

./scripts/generate.rsa.sh
./scripts/karafka.web.sh

rm -f ./tmp/pids/server.pid
bundle install

bundle exec rails db:prepare
bundle exec rails signup:seed_organization
bundle exec rails s -b 0.0.0.0
