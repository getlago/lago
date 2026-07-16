# frozen_string_literal: true

module EInvoices
  module Cii
    class TradeDelivery < BaseSerializer
      def initialize(xml:, delivery_date:)
        super(xml:)

        @delivery_date = delivery_date
      end

      def serialize
        xml.comment "Applicable Header Trade Delivery"
        xml["ram"].ApplicableHeaderTradeDelivery do
          xml["ram"].ActualDeliverySupplyChainEvent do
            xml["ram"].OccurrenceDateTime do
              xml["udt"].DateTimeString formatted_date(delivery_date), format: CCYYMMDD
            end
          end
        end
      end

      private

      attr_accessor :delivery_date
    end
  end
end
