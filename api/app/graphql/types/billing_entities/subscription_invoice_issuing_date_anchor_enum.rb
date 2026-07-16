# frozen_string_literal: true

module Types
  module BillingEntities
    class SubscriptionInvoiceIssuingDateAnchorEnum < Types::BaseEnum
      graphql_name "BillingEntitySubscriptionInvoiceIssuingDateAnchorEnum"
      description "Subscription Invoice Issuing Date Anchor Values"

      ::BillingEntity::SUBSCRIPTION_INVOICE_ISSUING_DATE_ANCHORS.keys.each do |code|
        value code
      end
    end
  end
end
