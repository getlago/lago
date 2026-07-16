#!/bin/bash

if [ "$RAILS_ENV" == "staging" ]
then
  bundle exec rake db:prepare
fi

rm -f ./tmp/pids/server.pid

if [ -v LAGO_CLICKHOUSE_MIGRATIONS_ENABLED ] && [ "$LAGO_CLICKHOUSE_MIGRATIONS_ENABLED" == "true" ]
then
  bundle exec rails db:migrate:primary
  bundle exec rails db:migrate:clickhouse
else
  bundle exec rails db:migrate
fi

bundle exec rails signup:seed_organization
exec bundle exec rails s -b ::
