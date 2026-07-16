# frozen_string_literal: true

module EInvoices
  module Ubl
    class PaymentMeans < BaseSerializer
      def initialize(xml:, type:, amount: nil)
        super(xml:)

        @type = type
        @amount = amount
      end

      def serialize
        xml.comment "Payment Means: #{payment_label(type)}"
        xml["cac"].PaymentMeans do
          xml["cbc"].PaymentMeansCode type
        end
      end

      private

      attr_accessor :type, :amount
    end
  end
end
