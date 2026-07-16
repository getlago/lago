# frozen_string_literal: true

module Fees
  module EstimateInstant
    class BatchPayInAdvanceService < BaseService
      def initialize(organization:, external_subscription_id:, events:)
        @organization = organization
        @timestamp = Time.current

        @events = events.map do |e|
          Event.new(
            organization_id: organization.id,
            code: e[:code],
            external_subscription_id: e[:external_subscription_id],
            properties: e[:properties] || {},
            transaction_id: e[:transaction_id] || SecureRandom.uuid,
            timestamp:
          )
        end

        subscription =
          organization.subscriptions.where(external_id: external_subscription_id)
            .where("date_trunc('millisecond', started_at::timestamp) <= ?::timestamp", timestamp)
            .where(
              "terminated_at IS NULL OR date_trunc('millisecond', terminated_at::timestamp) >= ?",
              timestamp
            )
            .order("terminated_at DESC NULLS FIRST, started_at DESC")
            .first

        super(organization:, subscription:)
      end

      def call
        return result.not_found_failure!(resource: "subscription") unless subscription

        if charges.none?
          return result.single_validation_failure!(field: :code, error_code: "does_not_match_an_instant_charge")
        end

        fees = []

        events.each do |event|
          # find all charges that match this event
          matched_charges = charges.select { |c| c.billable_metric.code == event.code }
          next unless matched_charges
          fees += matched_charges.map { |charge| estimate_charge_fees(charge, event) }
        end

        result.fees = fees
        result
      end

      private

      attr_reader :events, :timestamp

      def charges
        @charges ||= subscription
          .plan
          .charges
          .merge(Charge.percentage.or(Charge.standard))
          .pay_in_advance
          .includes(:billable_metric)
      end
    end
  end
end
