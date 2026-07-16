# frozen_string_literal: true

module Events
  class CommonFactory
    def self.new_instance(source:)
      case source.class.name
      when "Events::Common"
        source
      when "Hash"
        event = Events::Common.new(
          id: source["id"],
          organization_id: source["organization_id"],
          transaction_id: source["transaction_id"],
          external_subscription_id: source["external_subscription_id"],
          timestamp: Events::Common.timestamp_from_source(source),
          code: source["code"],
          properties: source["properties"]
        )

        if source["precise_total_amount_cents"].present?
          event.precise_total_amount_cents = BigDecimal(source["precise_total_amount_cents"].to_s)
        end

        event
      when "Event"
        Events::Common.new(
          id: source.id,
          organization_id: source.organization_id,
          transaction_id: source.transaction_id,
          external_subscription_id: source.external_subscription_id,
          timestamp: source.timestamp,
          code: source.code,
          properties: source.properties,
          precise_total_amount_cents: source.precise_total_amount_cents
        )
      when "Clickhouse::EventsRaw"
        Events::Common.new(
          id: nil,
          organization_id: source.organization_id,
          transaction_id: source.transaction_id,
          external_subscription_id: source.external_subscription_id,
          timestamp: source.timestamp,
          code: source.code,
          properties: source.properties,
          precise_total_amount_cents: source.precise_total_amount_cents
        )
      end
    end
  end
end
