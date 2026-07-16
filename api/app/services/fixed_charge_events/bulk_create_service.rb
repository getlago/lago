# frozen_string_literal: true

module FixedChargeEvents
  class BulkCreateService < BaseService
    Result = BaseResult[:fixed_charge_events]

    BATCH_SIZE = 1_000

    def initialize(events_attributes:)
      @events_attributes = events_attributes.to_a
      super
    end

    def call
      result.fixed_charge_events = []
      return result if events_attributes.empty?

      if events_attributes.any? { |attrs| attrs[:units].to_d.negative? }
        return result.single_validation_failure!(field: :units, error_code: "value_is_out_of_range")
      end

      now = Time.current
      rows = events_attributes.map { |attrs| attrs.merge(created_at: now, updated_at: now) }

      result.fixed_charge_events = rows.each_slice(BATCH_SIZE).flat_map do |batch|
        inserted = FixedChargeEvent.insert_all!(batch, returning: FixedChargeEvent.column_names) # rubocop:disable Rails/SkipsModelValidations
        inserted.map { |attrs| FixedChargeEvent.instantiate(attrs) }
      end

      result
    end

    private

    attr_reader :events_attributes
  end
end
