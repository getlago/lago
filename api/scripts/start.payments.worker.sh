#!/bin/bash

exec bundle exec sidekiq -C config/sidekiq/sidekiq_payments.yml
