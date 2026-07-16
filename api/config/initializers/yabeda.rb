# frozen_string_literal: true

require "yabeda"

# https://github.com/yabeda-rb/yabeda-prometheus?tab=readme-ov-file#multi-process-server-support
Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(
  dir: "/tmp/prometheus/"
)

Yabeda::Rails.config.ignore_actions = ["ApplicationController#health"]
Yabeda::Rails.config.buckets = [0.05, 0.1, 0.25, 0.5, 1, 5]

Yabeda.configure do
  default_tag :service, ENV["OTEL_SERVICE_NAME"] || "lago-api"
  default_tag :environment, Rails.env
  default_tag :version, ENV["LAGO_VERSION"] || "unknown"
end
