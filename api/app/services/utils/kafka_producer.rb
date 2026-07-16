# frozen_string_literal: true

module Utils
  class KafkaProducer
    def self.produce_async(topic:, key:, payload:)
      Karafka.producer.produce_async(topic:, key:, payload:)
      true
    rescue WaterDrop::Errors::MessageInvalidError,
      WaterDrop::Errors::ProduceError => e
      # The library will raise an error in two cases:
      # 1. Message is invalid (e.g., too large, or missing required fields)
      # 2. When the topic doesn't exist and the rdkafka producer has acknowledged it.
      #    See https://github.com/confluentinc/librdkafka/blob/f21766ffb663e1a54ef2f014b02b51509c834c31/CONFIGURATION.md?plain=1#L22
      # For all other cases, it will not raise as the message is produced async.
      raise if ENV["SENTRY_DSN"].blank?

      # Avoid raising error up to the end-user
      Sentry.capture_exception(e)
      false
    end
  end
end
