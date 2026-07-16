# frozen_string_literal: true

module EInvoices
  module Ubl
    class OrderReference < BaseSerializer
      def initialize(xml:, id:)
        super(xml:)

        @id = id
      end

      def serialize
        xml.comment "Order Reference"
        xml["cac"].OrderReference do
          xml["cbc"].ID id
        end
      end

      private

      attr_accessor :id
    end
  end
end
