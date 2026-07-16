# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure(&:use_all) if ENV["OTEL_EXPORTER"].present?

LagoTracer = OpenTelemetry.tracer_provider.tracer("lago")
