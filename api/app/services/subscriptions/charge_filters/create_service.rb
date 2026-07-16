# frozen_string_literal: true

module Subscriptions
  module ChargeFilters
    class CreateService < BaseService
      include Concerns::PlanOverrideConcern
      include Concerns::ChargeOverrideConcern

      Result = BaseResult[:charge_filter]

      def initialize(subscription:, charge:, params:)
        @subscription = subscription
        @charge = charge
        @params = params

        super
      end

      def call
        return result.forbidden_failure! unless License.premium?
        return result.not_found_failure!(resource: "subscription") unless subscription
        return result.not_found_failure!(resource: "charge") unless charge
        return result.single_validation_failure!(field: :values, error_code: "value_is_mandatory") if params[:values].blank?

        ActiveRecord::Base.transaction do
          target_plan = ensure_plan_override
          target_charge = find_or_create_charge_override(target_plan)

          sorted_values = params[:values].sort
          existing = target_charge.filters.find { |f| f.to_h.sort == sorted_values }
          return result.single_validation_failure!(field: :values, error_code: "value_already_exists") if existing

          create_result = ::ChargeFilters::CreateService.call!(
            charge: target_charge,
            params:
          )

          result.charge_filter = create_result.charge_filter
        end

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      rescue BaseService::FailedResult => e
        e.result
      end

      private

      attr_reader :subscription, :charge, :params
    end
  end
end
