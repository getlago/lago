#!/bin/bash
set -e

if [ "$RAILS_ENV" == "staging" ]
then
  bundle exec rake db:prepare
else
  bundle exec rake db:create
  bundle exec rails db:migrate
  bundle exec rails roles:seed_predefined

  if [ -v LAGO_CREATE_ORG ] && [ "$LAGO_CREATE_ORG" == "true" ]
  then
    bundle exec rails signup:seed_organization
  fi
fi
