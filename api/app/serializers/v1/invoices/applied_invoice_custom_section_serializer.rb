# frozen_string_literal: true

module V1
  module Invoices
    class AppliedInvoiceCustomSectionSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          lago_invoice_id: model.invoice_id,
          code: model.code,
          details: model.details,
          display_name: model.display_name,
          created_at: model.created_at.iso8601
        }
      end
    end
  end
end
