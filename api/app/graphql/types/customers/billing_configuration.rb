# frozen_string_literal: true

module Types
  module Customers
    class BillingConfiguration < Types::BaseObject
      graphql_name "CustomerBillingConfiguration"

      field :document_locale, String
      field :id, ID, null: false
      field :subscription_invoice_issuing_date_adjustment, Types::Customers::SubscriptionInvoiceIssuingDateAdjustmentEnum, null: true
      field :subscription_invoice_issuing_date_anchor, Types::Customers::SubscriptionInvoiceIssuingDateAnchorEnum, null: true
    end
  end
end
