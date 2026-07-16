# frozen_string_literal: true

module EInvoices
  module Cii
    class InvoiceReference < BaseSerializer
      def initialize(xml:, invoice_reference:)
        super(xml:)

        @invoice_reference = invoice_reference
      end

      def serialize
        xml.comment "Invoice reference"
        xml["ram"].InvoiceReferencedDocument do
          xml["ram"].IssuerAssignedID invoice_reference
        end
      end

      private

      attr_accessor :invoice_reference
    end
  end
end
