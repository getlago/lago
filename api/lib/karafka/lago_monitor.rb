# frozen_string_literal: true

class Karafka::LagoMonitor < ::Karafka::Instrumentation::Monitor
  TRACEABLE_EVENTS = %w[
    consumer.consumed
  ].freeze

  def instrument(event_id, payload = EMPTY_HASH, &block)
    return super unless TRACEABLE_EVENTS.include?(event_id)

    LagoTracer.in_span("karafka.#{payload[:caller].class}") { super }
  end
end
