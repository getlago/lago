# frozen_string_literal: true

module Commitments
  module Minimum
    module InArrears
      class FetchInvoicesService < Commitments::FetchInvoicesService
        private

        def dates_service
          ds = Subscriptions::DatesService.new_instance(
            subscription,
            invoice_subscription.timestamp,
            current_usage: subscription.terminated?
          )

          return ds unless subscription.terminated?

          Subscriptions::TerminatedDatesService.new(
            subscription:,
            invoice: invoice_subscription.invoice,
            date_service: ds
          ).call
        end

        def fetch_invoices
          unless plan.charges_or_fixed_charges_billed_in_monthly_split_intervals?
            return Invoice.where(id: invoice_subscription.invoice_id)
          end

          invoice_ids_query = subscription
            .invoice_subscriptions
            .where(
              "from_datetime >= ? AND to_datetime <= ?",
              dates_service.previous_beginning_of_period,
              dates_service.end_of_period
            ).select(:invoice_id)

          Invoice.where(id: invoice_ids_query)
        end
      end
    end
  end
end
