# frozen_string_literal: true

module Subscriptions
  module Concerns
    module FixedChargeUnitsOverrideDetectionConcern
      extend ActiveSupport::Concern

      PLAN_OVERRIDES_FIXED_CHARGE_ALLOWED_KEYS = %i[id units apply_units_immediately].freeze
      DEDICATED_ENDPOINT_ALLOWED_KEYS = %i[units apply_units_immediately].freeze

      private

      def units_only_fixed_charges_plan_overrides?(plan_overrides)
        plan_overrides = normalize_hash(plan_overrides)
        return false unless plan_overrides
        return false unless plan_overrides.keys == [:fixed_charges]

        fixed_charges = plan_overrides[:fixed_charges]
        return false unless fixed_charges&.any?

        fixed_charges.all? { |entry| units_only_fixed_charges_entry?(entry) }
      end

      def units_only_fixed_charge_params?(params)
        params = normalize_hash(params)
        return false unless params
        return false unless params.key?(:units)

        (params.keys - DEDICATED_ENDPOINT_ALLOWED_KEYS).empty?
      end

      def units_only_fixed_charges_entry?(entry)
        entry = normalize_hash(entry)
        return false unless entry
        return false unless entry.key?(:id) && entry.key?(:units)

        (entry.keys - PLAN_OVERRIDES_FIXED_CHARGE_ALLOWED_KEYS).empty?
      end

      def promote_units_overrides_to_fixed_charges_params(existing_params = [])
        overrides = subscription.fixed_charge_units_overrides.to_a
        return existing_params if overrides.empty?

        params_by_id = existing_params.each_with_object({}) do |entry, acc|
          entry = normalize_hash(entry)
          acc[entry[:id]] = entry if entry && entry[:id]
        end

        overrides.each do |override|
          params_by_id[override.fixed_charge_id] ||= {
            id: override.fixed_charge_id,
            units: override.units
          }
        end

        overrides.each(&:discard!)

        params_by_id.values
      end

      def normalize_hash(value)
        return nil if value.nil?
        return value.symbolize_keys if value.is_a?(Hash)
        return value.to_h.symbolize_keys if value.respond_to?(:to_h)

        nil
      end
    end
  end
end
