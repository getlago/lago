# frozen_string_literal: true

module V1
  class AppliedInvoiceCustomSectionSerializer < ModelSerializer
    def serialize
      {
        lago_id: model.id,
        invoice_custom_section_id: model.invoice_custom_section_id,
        created_at: model.created_at.iso8601,
        invoice_custom_section:
      }
    end

    private

    def invoice_custom_section
      ::V1::InvoiceCustomSectionSerializer.new(
        model.invoice_custom_section
      ).serialize
    end
  end
end
