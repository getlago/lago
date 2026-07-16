# frozen_string_literal: true

module Types
  module Customers
    class SubscriptionInvoiceIssuingDateAdjustmentEnum < Types::BaseEnum
      graphql_name "CustomerSubscriptionInvoiceIssuingDateAdjustmentEnum"
      description "Subscription Invoice Issuing Date Adjustment Values"

      ::Customer::SUBSCRIPTION_INVOICE_ISSUING_DATE_ADJUSTMENTS.keys.each do |code|
        value code
      end
    end
  end
end
