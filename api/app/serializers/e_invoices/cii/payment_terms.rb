# frozen_string_literal: true

module EInvoices
  module Cii
    class PaymentTerms < BaseSerializer
      def initialize(xml:, due_date:, description:)
        super(xml:)

        @description = description
        @due_date = due_date
      end

      def serialize
        xml.comment "Payment Terms"
        xml["ram"].SpecifiedTradePaymentTerms do
          xml["ram"].Description description
          xml["ram"].DueDateDateTime do
            xml["udt"].DateTimeString formatted_date(due_date), format: CCYYMMDD
          end
        end
      end

      private

      attr_accessor :due_date, :description
    end
  end
end
