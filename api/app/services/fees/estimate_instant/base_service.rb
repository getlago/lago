# frozen_string_literal: true

module Fees
  module EstimateInstant
    class BaseService < ::BaseService
      def initialize(organization:, subscription:)
        @organization = organization
        @subscription = subscription

        super
      end

      private

      attr_reader :subscription, :organization
      delegate :customer, to: :subscription

      def estimate_charge_fees(charge, event)
        charge_filter = ChargeFilters::EventMatchingService.call(charge:, event:).charge_filter
        properties = charge_filter&.properties || charge.properties

        # Todo: perhaps this should live in its own service
        Events::CalculateExpressionService.call(organization:, event:)
        billable_metric = charge.billable_metric
        base_unit = 0
        # in case for the aggregations we do not use field_name, we count each event as 1 unit
        base_unit = 1 if charge.billable_metric.field_name.nil?
        units = BigDecimal(event.properties[charge.billable_metric.field_name] || base_unit)
        units = BillableMetrics::Aggregations::ApplyRoundingService.call!(billable_metric:, units:).units

        estimate_result = estimate_class(charge).call!(properties:, units:)

        amount = estimate_result.amount
        # NOTE: amount_result should be  a BigDecimal, we need to round it
        # to the currency decimals and transform it into currency cents
        rounded_amount = amount.round(currency.exponent)
        amount_cents = rounded_amount * currency.subunit_to_unit
        unit_amount = rounded_amount.zero? ? BigDecimal("0") : rounded_amount / units
        unit_amount_cents = unit_amount * currency.subunit_to_unit

        # construct payload directly
        {
          lago_id: nil,
          lago_charge_id: charge.id,
          lago_charge_filter_id: charge_filter&.id,
          lago_invoice_id: nil,
          lago_true_up_fee_id: nil,
          lago_true_up_parent_fee_id: nil,
          lago_subscription_id: subscription.id,
          external_subscription_id: subscription.external_id,
          lago_customer_id: customer.id,
          external_customer_id: customer.external_id,
          item: {
            type: "charge",
            code: billable_metric.code,
            name: billable_metric.name,
            description: billable_metric.description,
            invoice_display_name: charge.invoice_display_name.presence || billable_metric.name,
            filters: charge_filter&.to_h,
            filter_invoice_display_name: charge_filter&.display_name,
            lago_item_id: billable_metric.id,
            item_type: BillableMetric.name,
            grouped_by: {}
          },
          pay_in_advance: true,
          invoiceable: charge.invoiceable,
          amount_cents:,
          amount_currency: currency.iso_code,
          precise_amount: amount,
          precise_total_amount: amount,
          taxes_amount_cents: 0,
          taxes_precise_amount: 0,
          taxes_rate: 0,
          total_amount_cents: amount_cents,
          total_amount_currency: currency.iso_code,
          units: units,
          description: nil,
          precise_unit_amount: unit_amount_cents,
          precise_coupons_amount_cents: "0.0",
          events_count: 1,
          payment_status: "pending",
          created_at: nil,
          succeeded_at: nil,
          failed_at: nil,
          refunded_at: nil,
          amount_details: nil,
          event_transaction_id: event.transaction_id
        }
      end

      def estimate_class(charge)
        if charge.percentage?
          Charges::EstimateInstant::PercentageService
        elsif charge.standard?
          Charges::EstimateInstant::StandardService
        end
      end

      def currency
        @currency ||= subscription.plan.amount.currency
      end
    end
  end
end
