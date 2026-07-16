# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.colorize_logging = Rails.env.development?

  config.lograge.ignore_actions = ["ApplicationController#health"]

  config.lograge.custom_options = lambda do |event|
    # If ENV[OTEL_EXPORTER] is not set, the span context will have all zero values.
    span = OpenTelemetry::Trace.current_span

    {
      level: event.payload[:level],
      ddsource: "ruby",
      params: (event.payload[:params] || {}).reject { |k| %w[controller action].include?(k) },
      organization_id: event.payload[:organization_id],
      trace_id: span.context.hex_trace_id,
      span_id: span.context.hex_span_id
    }
  end
end
