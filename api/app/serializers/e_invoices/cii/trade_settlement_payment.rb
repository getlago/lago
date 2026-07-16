# frozen_string_literal: true

module EInvoices
  module Cii
    class TradeSettlementPayment < BaseSerializer
      def initialize(xml:, resource:, type:, amount: nil)
        super(xml:, resource:)

        @type = type
        @amount = amount
      end

      def serialize
        xml.comment "Payment Means: #{payment_label(type)}"
        xml["ram"].SpecifiedTradeSettlementPaymentMeans do
          xml["ram"].TypeCode type
          xml["ram"].Information payment_information(type, amount)
          card_attributes if type == CREDIT_CARD_PAYMENT
        end
      end

      private

      attr_accessor :type, :amount

      def card_attributes
        xml["ram"].ApplicableTradeSettlementFinancialCard do
          xml["ram"].ID resource.card_last_digits
        end
      end
    end
  end
end
