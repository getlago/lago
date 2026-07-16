# frozen_string_literal: true

module EInvoices
  module Ubl
    class Delivery < BaseSerializer
      def initialize(xml:, delivery_date:)
        super(xml:)

        @delivery_date = delivery_date
      end

      def serialize
        xml.comment "Delivery Information"
        xml["cac"].Delivery do
          xml["cbc"].ActualDeliveryDate formatted_date(delivery_date)
        end
      end

      private

      attr_accessor :delivery_date
    end
  end
end
