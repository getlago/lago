# frozen_string_literal: true

module Fees
  module Commitments
    module Minimum
      class CalculatePreviewFeeService < BuildFeeBaseService
        Result = BaseResult[:fee]

        def initialize(invoice_subscription:, preview_fees_amount_cents:, preview_fees_precise_amount_cents:)
          @preview_fees_amount_cents = preview_fees_amount_cents
          @preview_fees_precise_amount_cents = preview_fees_precise_amount_cents

          super(invoice_subscription:)
        end

        def call
          return result unless minimum_commitment
          return result if pay_in_advance_first_period?

          true_up_amount_cents = [commitment_amount_cents - fees_total_amount_cents, 0].max
          return result if true_up_amount_cents.zero?

          true_up_precise_amount_cents = [commitment_amount_cents - fees_total_precise_amount_cents, 0].max

          result.fee = build_fee(
            amount_cents: true_up_amount_cents,
            precise_amount_cents: true_up_precise_amount_cents
          )
          result
        end

        private

        attr_reader :preview_fees_amount_cents, :preview_fees_precise_amount_cents

        def commitment_amount_cents
          @commitment_amount_cents ||= (minimum_commitment.amount_cents * proration_coefficient).round
        end

        def proration_coefficient
          @proration_coefficient ||= days_total.positive? ? days_active / days_total.to_f : 1.0
        end

        def days_active
          first_invoice_subscription_datetime = subscription.invoice_subscriptions
            .starting_from(dates_service.previous_beginning_of_period)
            .pick(:from_datetime)
          from_datetime = first_invoice_subscription_datetime || reconciliation_invoice_subscription.from_datetime
          end_datetime = subscription.terminated? ? subscription.terminated_at : reconciliation_invoice_subscription.to_datetime

          ::Utils::Datetime.date_diff_with_timezone(
            from_datetime,
            end_datetime,
            subscription.customer.applicable_timezone
          )
        end

        def days_total
          ::Utils::Datetime.date_diff_with_timezone(
            dates_service.previous_beginning_of_period,
            dates_service.end_of_period,
            subscription.customer.applicable_timezone
          )
        end

        def dates_service
          current_usage = subscription.plan.pay_in_advance? || subscription.terminated?
          @dates_service ||= ::Subscriptions::DatesService.new_instance(
            subscription,
            reconciliation_invoice_subscription.timestamp,
            current_usage:
          )
        end

        def fees_total_amount_cents
          db_historical_fees_amount_cents + preview_fees_amount_cents
        end

        def fees_total_precise_amount_cents
          db_historical_fees_precise_amount_cents + preview_fees_precise_amount_cents
        end

        def db_historical_fees_amount_cents
          charge_fees.sum(:amount_cents) +
            charge_in_advance_fees.sum(:amount_cents) +
            fixed_charge_fees.sum(:amount_cents) +
            fixed_charge_in_advance_fees.sum(:amount_cents)
        end

        def db_historical_fees_precise_amount_cents
          charge_fees.sum(:precise_amount_cents) +
            charge_in_advance_fees.sum(:precise_amount_cents) +
            fixed_charge_fees.sum(:precise_amount_cents) +
            fixed_charge_in_advance_fees.sum(:precise_amount_cents)
        end

        def charge_fees
          charge_fees_base.where(charge: {pay_in_advance: false})
        end

        def charge_in_advance_fees
          charge_fees_base.where(charge: {pay_in_advance: true}, pay_in_advance: true)
        end

        def fixed_charge_fees
          fixed_charge_fees_base.where(fixed_charge: {pay_in_advance: false})
        end

        def fixed_charge_in_advance_fees
          fixed_charge_fees_base.where(fixed_charge: {pay_in_advance: true}, pay_in_advance: true)
        end

        def charge_fees_base
          @charge_fees_base ||= Fee.charge
            .joins(:charge)
            .where(subscription_id: subscription.id)
            .where("(fees.properties->>'charges_from_datetime')::timestamptz >= ?", dates_service.previous_beginning_of_period)
            .where("(fees.properties->>'charges_to_datetime')::timestamptz <= ?", dates_service.end_of_period&.iso8601(3))
        end

        def fixed_charge_fees_base
          @fixed_charge_fees_base ||= Fee.fixed_charge
            .joins(:fixed_charge)
            .where(subscription_id: subscription.id)
            .where("(fees.properties->>'fixed_charges_from_datetime')::timestamptz >= ?", dates_service.previous_beginning_of_period)
            .where("(fees.properties->>'fixed_charges_to_datetime')::timestamptz <= ?", dates_service.end_of_period&.iso8601(3))
        end
      end
    end
  end
end
