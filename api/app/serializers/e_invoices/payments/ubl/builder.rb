# frozen_string_literal: true

module EInvoices
  module Payments::Ubl
    class Builder < EInvoices::Ubl::BaseSerializer
      include Payments::Common

      def initialize(xml:, payment:)
        super(xml:, resource: payment)

        @payment = payment
      end

      def serialize
        xml.ApplicationResponse(RECEIPTS_NAMESPACES) do
          xml.comment "UBL Version and Customization"
          xml["cbc"].UBLVersionID "2.1"
          xml["cbc"].CustomizationID "urn:oasis:names:specification:ubl:xpath:ApplicationResponse-2.4"
          xml["cbc"].ProfileID "urn:oasis:names:specification:ubl:schema:xsd:ApplicationResponse-2"
          xml["cbc"].ID payment_receipt.number
          xml["cbc"].IssueDate formatted_date(payment.created_at)
          xml["cbc"].Note notes.to_sentence

          Ubl::SenderParty.serialize(xml:, resource:)
          Ubl::ReceiverParty.serialize(xml:, resource:)

          payment.invoices.each do |invoice|
            Ubl::DocumentResponse.serialize(xml:, response: paid_response, document: invoice_document(invoice))
          end
        end
      end

      private

      attr_accessor :payment

      def paid_response
        Ubl::DocumentResponse::Response.new(
          code: PAID,
          description: notes.to_sentence,
          date: payment.created_at
        )
      end

      def invoice_document(invoice)
        Ubl::DocumentResponse::Document.new(
          id: invoice.number,
          issue_date: invoice.issuing_date,
          type_code: invoice_type_code(invoice),
          type: invoice.class.to_s,
          description: "Invoice ID from payment system: #{invoice.id}"
        )
      end
    end
  end
end
