# frozen_string_literal: true

begin
  require "sidekiq-pro"
rescue LoadError
  if ENV["LAGO_SIDEKIQ_PRO_REQUIRED"] == "true"
    raise "Sidekiq Pro is required. Please make sure it's properly installed."
  end
  Rails.logger.info "Sidekiq Pro is not installed. Reliability features will not be available."
end

require "socket"
require "sidekiq/middleware/current_attributes"
require "lago/redis_config_builder"

LIVENESS_PORT = 8080

redis_config = Lago::RedisConfigBuilder.new
  .with_options(pool_timeout: 5)
  .sidekiq

if ENV["LAGO_SIDEKIQ_WEB"] == "true"
  require "sidekiq/web"
  require "sidekiq/prometheus/exporter"

  Sidekiq::Web.use(ActionDispatch::Cookies)
  Sidekiq::Web.use(ActionDispatch::Session::CookieStore, key: "_interslice_session")
end

def configure_sidekiq_pro_metrics(config)
  statsd_endpoint = ENV.fetch("LAGO_SIDEKIQ_STATSD_ENDPOINT", nil)
  if statsd_endpoint.nil?
    Rails.logger.warn "LAGO_SIDEKIQ_STATSD_ENDPOINT not set, Sidekiq Pro metrics will not be reported"
    return
  end

  statsd_host, statsd_port = statsd_endpoint.split(":")
  if statsd_host.empty? || statsd_port.nil? || statsd_port.empty?
    Rails.logger.error "LAGO_SIDEKIQ_STATSD_ENDPOINT invalid format, expected host:port, got: #{statsd_endpoint}"
    return
  end

  require "datadog/statsd"

  config.dogstatsd = -> {
    Datadog::Statsd.new(statsd_host, statsd_port.to_i,
      tags: ["env:#{config[:environment]}", "service:sidekiq"],

      namespace: Rails.application.name)
  }

  config.server_middleware do |chain|
    require "sidekiq/middleware/server/statsd"
    chain.add Sidekiq::Middleware::Server::Statsd
  end
end

Sidekiq.configure_server do |config|
  if Sidekiq.pro?
    # Super fetch is only available in Sidekiq Pro. See https://github.com/sidekiq/sidekiq/wiki/Reliability.
    config.super_fetch!
    # https://github.com/sidekiq/sidekiq/wiki/Pro-Metrics#enabling-metrics
    # As of Sidekiq Pro 8.0, this is the recommended Statsd tag/namespace configuration.
    # Read more about global tags: https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/
    configure_sidekiq_pro_metrics(config)
  end
  config.redis = redis_config
  config.logger = nil
  config.average_scheduled_poll_interval = ENV.fetch("LAGO_SIDEKIQ_AVERAGE_SCHEDULED_POLL_INTERVAL", 5).to_f
  config[:max_retries] = 0
  config[:dead_max_jobs] = ENV.fetch("LAGO_SIDEKIQ_MAX_DEAD_JOBS", 100_000).to_i
  config.on(:startup) do
    Sidekiq.logger.info "Starting liveness server on #{LIVENESS_PORT}"
    Thread.start do # rubocop:disable ThreadSafety/NewThread
      server = TCPServer.new("0.0.0.0", LIVENESS_PORT)
      loop do
        Thread.start(server.accept) do |socket| # rubocop:disable ThreadSafety/NewThread
          request = socket.gets
          sidekiq_response = ::Sidekiq.redis { |r| r.ping }

          if sidekiq_response.eql?("PONG")
            response = "Live!\n"
            socket.print "HTTP/1.1 200 OK\r\n" \
                       "Content-Type: text/plain\r\n" \
                       "Content-Length: #{response.bytesize}\r\n" \
                       "Connection: close\r\n"
          else
            response = "Sidekiq is not ready: Sidekiq.redis.ping returned #{request.inspect} instead of PONG\n"
            Sidekiq.logger.error(response)
            socket.print "HTTP/1.1 404 OK\r\n" \
                       "Content-Type: text/plain\r\n" \
                       "Content-Length: #{response.bytesize}\r\n" \
                       "Connection: close\r\n"
          end
          socket.print "\r\n"
          socket.print response
          socket.close
        rescue
          response = "Sidekiq is not ready\n"
          Sidekiq.logger.error(response)
          socket.print "HTTP/1.1 404 OK\r\n" \
                       "Content-Type: text/plain\r\n" \
                       "Content-Length: #{response.bytesize}\r\n" \
                       "Connection: close\r\n"
          socket.print "\r\n"
          socket.print response
          socket.close
        end
      end
    end
  end

  if Rails.env.development? && ENV["SIDEKIQ_PROFILING_ENABLED"] == "true"
    config.server_middleware do |chain|
      chain.prepend(Sidekiq::ProfilingMiddleware, dir: "tmp/profiling")
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
  config.logger = Sidekiq::Logger.new($stdout)
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
end

Sidekiq::CurrentAttributes.persist("CurrentContext")
