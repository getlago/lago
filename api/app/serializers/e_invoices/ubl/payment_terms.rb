# frozen_string_literal: true

module EInvoices
  module Ubl
    class PaymentTerms < BaseSerializer
      def initialize(xml:, note:)
        super(xml:)

        @note = note
      end

      def serialize
        xml.comment "Payment Terms"
        xml["cac"].PaymentTerms do
          xml["cbc"].Note note
        end
      end

      private

      attr_accessor :note
    end
  end
end
