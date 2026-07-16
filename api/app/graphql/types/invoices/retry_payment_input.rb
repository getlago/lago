# frozen_string_literal: true

module Types
  module Invoices
    class RetryPaymentInput < BaseInputObject
      description "Retry payment input arguments"

      argument :id, ID, required: true
      argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
    end
  end
end
