#!/bin/bash
./scripts/generate.rsa.sh

bundle install
bundle exec rails db:prepare
