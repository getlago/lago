#!/bin/bash

exec bundle exec sidekiq -C config/sidekiq/sidekiq_dedicated.yml
