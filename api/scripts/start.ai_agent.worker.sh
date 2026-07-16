#!/bin/bash

exec bundle exec sidekiq -C config/sidekiq/sidekiq_ai_agent.yml
