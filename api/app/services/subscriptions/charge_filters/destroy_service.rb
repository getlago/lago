# frozen_string_literal: true

module Subscriptions
  module ChargeFilters
    class DestroyService < BaseService
      include Concerns::PlanOverrideConcern
      include Concerns::ChargeOverrideConcern

      Result = BaseResult[:charge_filter]

      def initialize(subscription:, charge:, charge_filter:)
        @subscription = subscription
        @charge = charge
        @charge_filter = charge_filter

        super
      end

      def call
        return result.forbidden_failure! unless License.premium?
        return result.not_found_failure!(resource: "subscription") unless subscription
        return result.not_found_failure!(resource: "charge") unless charge
        return result.not_found_failure!(resource: "charge_filter") unless charge_filter

        ActiveRecord::Base.transaction do
          target_plan = ensure_plan_override
          target_charge = find_or_create_charge_override(target_plan)
          target_filter = find_filter_on_charge(target_charge)

          return result.not_found_failure!(resource: "charge_filter") unless target_filter

          destroy_result = ::ChargeFilters::DestroyService.call!(charge_filter: target_filter)

          result.charge_filter = destroy_result.charge_filter
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        e.result
      end

      private

      attr_reader :subscription, :charge, :charge_filter

      def find_filter_on_charge(target_charge)
        filter_values_hash = charge_filter.to_h
        target_charge.filters.find { |f| f.to_h.sort == filter_values_hash.sort }
      end
    end
  end
end
