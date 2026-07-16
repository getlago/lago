# frozen_string_literal: true

module Types
  module BillingEntities
    class SubscriptionInvoiceIssuingDateAdjustmentEnum < Types::BaseEnum
      graphql_name "BillingEntitySubscriptionInvoiceIssuingDateAdjustmentEnum"
      description "Subscription Invoice Issuing Date Adjustment Values"

      ::BillingEntity::SUBSCRIPTION_INVOICE_ISSUING_DATE_ADJUSTMENTS.keys.each do |code|
        value code
      end
    end
  end
end
