# frozen_string_literal: true

module Subscriptions
  module Concerns
    module FixedChargeUnitsOverridePromotionConcern
      extend ActiveSupport::Concern

      private

      def promote_units_overrides_to_fixed_charges_params(existing_params = [])
        overrides = subscription.fixed_charge_units_overrides.to_a
        return existing_params if overrides.empty?

        params_by_id = existing_params.each_with_object({}) do |entry, acc|
          entry = entry.to_h.symbolize_keys if entry.respond_to?(:to_h)
          acc[entry[:id]] = entry if entry.is_a?(Hash) && entry[:id]
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
    end
  end
end
