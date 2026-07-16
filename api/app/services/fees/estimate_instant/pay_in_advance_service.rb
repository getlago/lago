# frozen_string_literal: true

module Fees
  module EstimateInstant
    class PayInAdvanceService < BaseService
      def initialize(organization:, params:)
        @event = Event.new(
          organization_id: organization.id,
          code: params[:code],
          external_subscription_id: params[:external_subscription_id],
          properties: params[:properties] || {},
          transaction_id: params[:transaction_id] || SecureRandom.uuid,
          timestamp: Time.current
        )

        super(organization:, subscription: event.subscription)
      end

      def call
        return result.not_found_failure!(resource: "subscription") unless subscription

        if charges.none?
          return result.single_validation_failure!(field: :code, error_code: "does_not_match_an_instant_charge")
        end

        fees = charges.map { |charge| estimate_charge_fees(charge, event) }

        result.fees = fees
        result
      end

      private

      attr_reader :event

      def charges
        @charges ||= subscription
          .plan
          .charges
          .merge(Charge.percentage.or(Charge.standard))
          .pay_in_advance
          .joins(:billable_metric)
          .where(billable_metric: {code: event.code})
      end
    end
  end
end
