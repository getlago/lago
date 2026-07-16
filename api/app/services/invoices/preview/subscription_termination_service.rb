# frozen_string_literal: true

module Invoices
  module Preview
    class SubscriptionTerminationService < BaseService
      Result = BaseResult[:subscriptions]

      def initialize(current_subscription:, terminated_at:)
        @current_subscription = current_subscription
        @terminated_at = terminated_at
        super
      end

      def call
        return result.not_found_failure!(resource: "subscription") unless current_subscription

        unless parsed_terminated_at
          return result.single_validation_failure!(
            error_code: "invalid_timestamp",
            field: :terminated_at
          )
        end

        if parsed_terminated_at.past?
          return result.single_validation_failure!(
            error_code: "cannot_be_in_past",
            field: :terminated_at
          )
        end

        current_subscription.assign_attributes(
          status: :terminated,
          terminated_at:
        )

        result.subscriptions = [current_subscription]
        result
      end

      private

      attr_reader :current_subscription, :terminated_at

      def parsed_terminated_at
        return unless Utils::Datetime.valid_format?(terminated_at, format: :any)

        Time.zone.parse(terminated_at)
      end
    end
  end
end
