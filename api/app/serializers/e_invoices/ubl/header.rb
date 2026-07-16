# frozen_string_literal: true

module EInvoices
  module Ubl
    class Header < BaseSerializer
      def initialize(xml:, resource:, type_code:, notes: [])
        super(xml:, resource:)

        @type_code = type_code
        @notes = notes
      end

      def serialize
        xml.comment "Invoice Header Information"
        xml["cbc"].ID resource.number
        xml["cbc"].IssueDate formatted_date(resource.issuing_date)
        xml["cbc"].send(type_code_tag, type_code)
        notes.each do |note|
          xml["cbc"].Note note
        end
        xml["cbc"].DocumentCurrencyCode resource.currency
        xml["cbc"].BuyerReference resource.customer.external_id if de_billing_entity?
      end

      private

      attr_accessor :type_code, :notes

      def type_code_tag
        case type_code
        when COMMERCIAL_INVOICE, PREPAID_INVOICE, SELF_BILLED_INVOICE
          :InvoiceTypeCode
        when CREDIT_NOTE
          :CreditNoteTypeCode
        else
          raise "Unknow resource type code #{type_code}"
        end
      end
    end
  end
end
