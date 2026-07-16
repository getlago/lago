# frozen_string_literal: true

module Types
  module Invoices
    class PaymentStatusTypeEnum < Types::BaseEnum
      graphql_name "InvoicePaymentStatusTypeEnum"

      Invoice::PAYMENT_STATUS.each do |type|
        value type
      end
    end
  end
end
