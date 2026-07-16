# frozen_string_literal: true

module Types
  module Payables
    class Object < Types::BaseUnion
      graphql_name "Payable"

      possible_types Types::Invoices::Object, Types::PaymentRequests::Object

      def self.resolve_type(object, _context)
        case object.class.to_s
        when "Invoice"
          Types::Invoices::Object
        when "PaymentRequest"
          Types::PaymentRequests::Object
        else
          raise "Unexpected payable type: #{object.inspect}"
        end
      end
    end
  end
end
