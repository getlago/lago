# frozen_string_literal: true

module Types
  module Customers
    class BillingConfigurationInput < BaseInputObject
      graphql_name "CustomerBillingConfigurationInput"

      argument :document_locale, String, required: false, permissions: %w[customers:create customers:update]
      argument :subscription_invoice_issuing_date_adjustment, Types::Customers::SubscriptionInvoiceIssuingDateAdjustmentEnum, required: false, permissions: %w[customers:create customers:update]
      argument :subscription_invoice_issuing_date_anchor, Types::Customers::SubscriptionInvoiceIssuingDateAnchorEnum, required: false, permissions: %w[customers:create customers:update]
    end
  end
end
