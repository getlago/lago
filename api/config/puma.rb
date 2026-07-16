# frozen_string_literal: true

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", 0)
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
#
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"
worker_timeout 12 if ENV.fetch("RAILS_ENV", "production") == "production"

worker_shutdown_timeout 30
before_worker_boot do
  $shutdown_requested = false # rubocop:disable Style/GlobalVars
end

before_worker_shutdown do
  $shutdown_requested = true # rubocop:disable Style/GlobalVars
  sleep 5  # let k8s remove from endpoints
end

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("PORT", 3000)

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV", "development")

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
#
workers ENV.fetch("WEB_CONCURRENCY", 0)

# Ensure we flush and close Karafka producer when puma is shutting down
if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 0
  before_worker_shutdown do
    ::Karafka.producer.close
  end
else
  after_stopped do
    ::Karafka.producer.close
  end
end

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
#
preload_app! if ENV["WEB_CONCURRENCY"].present?

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Activate Yabeda
activate_control_app
plugin :yabeda
