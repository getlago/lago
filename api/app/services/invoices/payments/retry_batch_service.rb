# frozen_string_literal: true

module Invoices
  module Payments
    class RetryBatchService < BaseService
      Result = BaseResult[:invoice, :invoices]

      def initialize(organization_id:)
        @organization_id = organization_id

        super
      end

      def call_async
        Invoices::Payments::RetryAllJob.perform_later(organization_id:, invoice_ids: invoices.ids)

        result.invoices = invoices

        result
      end

      def call(invoice_ids)
        processed_invoices = []
        Invoice.where(id: invoice_ids).find_each do |invoice|
          result = Invoices::Payments::RetryService.new(invoice:).call

          return result unless result.success?

          processed_invoices << result.invoice
        end

        result.invoices = processed_invoices.compact

        result
      end

      private

      attr_reader :organization_id

      def invoices
        return @invoices if defined? @invoices

        @invoices = begin
          invoices = organization.invoices.where(payment_status: %w[pending failed])
          invoices = invoices.where(ready_for_payment_processing: true)
          invoices = invoices.where(status: "finalized")

          invoices
        end
      end

      def organization
        @organization ||= Organization.find_by!(id: organization_id)
      end
    end
  end
end
