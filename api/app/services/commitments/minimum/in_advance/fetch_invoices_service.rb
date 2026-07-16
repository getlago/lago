# frozen_string_literal: true

module Commitments
  module Minimum
    module InAdvance
      class FetchInvoicesService < Commitments::FetchInvoicesService
        private

        def dates_service
          ds = Subscriptions::DatesService.new_instance(
            subscription,
            invoice_subscription.timestamp,
            current_usage: true
          )

          return ds unless subscription.terminated?

          Subscriptions::TerminatedDatesService.new(
            subscription:,
            invoice: invoice_subscription.invoice,
            date_service: ds
          ).call
        end

        def fetch_invoices
          return Invoice.where(id: invoice_subscription.invoice_id) unless previous_invoice_subscription

          date_service = Subscriptions::DatesService.new_instance(
            subscription,
            previous_invoice_subscription.timestamp,
            current_usage: true
          )

          invoice_ids_query = fetch_invoice_ids_for_charges(date_service:) + fetch_invoice_ids_for_fixed_charges(date_service:)
          Invoice.where(id: invoice_ids_query)
        end

        def previous_invoice_subscription
          invoice_subscription.previous_invoice_subscription
        end

        def fetch_invoice_ids_for_charges(date_service:)
          # If charges are NOT billed monthly, fees are on the current invoice (billed in arrears)
          return [invoice_subscription.invoice_id] unless plan.charges_billed_in_monthly_split_intervals?

          subscription
            .invoice_subscriptions
            .where(
              "(charges_from_datetime >= ? AND charges_to_datetime <= ?)",
              date_service.previous_beginning_of_period,
              date_service.end_of_period
            ).pluck(:invoice_id)
        end

        def fetch_invoice_ids_for_fixed_charges(date_service:)
          # If fixed_charges are NOT billed monthly, fees are on the current invoice (billed in arrears)
          return [invoice_subscription.invoice_id] unless plan.fixed_charges_billed_in_monthly_split_intervals?

          subscription
            .invoice_subscriptions
            .where(
              "(fixed_charges_from_datetime >= ? AND fixed_charges_to_datetime <= ?)",
              date_service.previous_beginning_of_period,
              date_service.end_of_period
            ).pluck(:invoice_id)
        end
      end
    end
  end
end
