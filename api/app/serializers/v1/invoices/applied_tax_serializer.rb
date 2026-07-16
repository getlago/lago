# frozen_string_literal: true

module V1
  module Invoices
    class AppliedTaxSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          lago_invoice_id: model.invoice_id,
          lago_tax_id: model.tax_id,
          tax_name: model.tax_name,
          tax_code: model.tax_code,
          tax_rate: model.tax_rate,
          tax_description: model.tax_description,
          amount_cents: model.amount_cents,
          amount_currency: model.amount_currency,
          fees_amount_cents: model.fees_amount_cents,
          created_at: model&.created_at&.iso8601
        }
      end
    end
  end
end
