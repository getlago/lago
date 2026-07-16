#!/bin/bash

rm -f ./tmp/pids/server.pid
exec bundle exec rails s -b ::
