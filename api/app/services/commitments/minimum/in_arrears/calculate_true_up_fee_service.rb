# frozen_string_literal: true

module Commitments
  module Minimum
    module InArrears
      class CalculateTrueUpFeeService < Commitments::Minimum::CalculateTrueUpFeeService
        private

        def subscription_fees
          invoices_result = FetchInvoicesService.call(commitment: minimum_commitment, invoice_subscription:)

          Fee
            .subscription
            .joins(subscription: :plan)
            .where(
              subscription_id: subscription.id,
              invoice_id: invoices_result.invoices.ids,
              plan: {pay_in_advance: false}
            )
        end

        def charge_fees
          Fee
            .charge
            .joins(:charge)
            .where(
              subscription_id: subscription.id,
              charge: {pay_in_advance: false}
            )
            .where(
              "(fees.properties->>'charges_from_datetime') >= ?",
              dates_service.previous_beginning_of_period
            )
            .where(
              "(fees.properties->>'charges_to_datetime') <= ?",
              dates_service.end_of_period&.iso8601(3)
            )
        end

        def charge_in_advance_fees
          Fee
            .charge
            .joins(:charge)
            .where(
              subscription_id: subscription.id,
              charge: {pay_in_advance: true},
              pay_in_advance: true
            )
            .where(
              "(fees.properties->>'charges_from_datetime') >= ?",
              dates_service.previous_beginning_of_period
            )
            .where(
              "(fees.properties->>'charges_to_datetime') <= ?",
              dates_service.end_of_period&.iso8601(3)
            )
        end

        def charge_in_advance_recurring_fees
          if !invoice_subscription.previous_invoice_subscription && !subscription.plan.charges_billed_in_monthly_split_intervals?
            return Fee.none
          end

          is = if subscription.plan.charges_billed_in_monthly_split_intervals?
            invoice_subscription
          else
            invoice_subscription.previous_invoice_subscription
          end

          dates_service = Commitments::Minimum::InArrears::DatesService.new(
            commitment: minimum_commitment,
            invoice_subscription: is
          ).call

          scope = Fee
            .charge
            .joins(:charge)
            .joins(charge: :billable_metric)
            .where(billable_metric: {recurring: true})
            .where(
              subscription_id: subscription.id,
              charge: {pay_in_advance: true},
              pay_in_advance: false
            )
            .where(
              "(fees.properties->>'charges_to_datetime') <= ?",
              dates_service.end_of_period&.iso8601(3)
            )

          # rubocop:disable Style/ConditionalAssignment
          if subscription.plan.charges_billed_in_monthly_split_intervals?
            scope = scope
              .where(
                "(fees.properties->>'charges_from_datetime') >= ?",
                dates_service.previous_beginning_of_period - 1.month
              )
              .where.not(invoice_id: invoice_subscription.invoice_id)
          else
            scope = scope.where(
              "(fees.properties->>'charges_from_datetime') >= ?",
              dates_service.previous_beginning_of_period
            )
          end
          # rubocop:enable Style/ConditionalAssignment

          scope
        end

        def fixed_charge_fees
          Fee
            .fixed_charge
            .joins(:fixed_charge)
            .where(
              subscription_id: subscription.id,
              fixed_charge: {pay_in_advance: false}
            )
            .where(
              "(fees.properties->>'fixed_charges_from_datetime') >= ?",
              dates_service.previous_beginning_of_period
            )
            .where(
              "(fees.properties->>'fixed_charges_to_datetime') <= ?",
              dates_service.end_of_period&.iso8601(3)
            )
        end

        def fixed_charge_in_advance_fees
          Fee
            .fixed_charge
            .joins(:fixed_charge)
            .where(
              subscription_id: subscription.id,
              fixed_charge: {pay_in_advance: true},
              pay_in_advance: true
            )
            .where(
              "(fees.properties->>'fixed_charges_from_datetime') >= ?",
              dates_service.previous_beginning_of_period
            )
            .where(
              "(fees.properties->>'fixed_charges_to_datetime') <= ?",
              dates_service.end_of_period&.iso8601(3)
            )
        end

        def dates_service
          @dates_service ||= Commitments::DatesService.new_instance(
            commitment: minimum_commitment,
            invoice_subscription:
          ).call
        end
      end
    end
  end
end
