# frozen_string_literal: true

module Types
  module BillingEntities
    class BillingConfigurationInput < Types::BaseInputObject
      graphql_name "BillingEntityBillingConfigurationInput"

      argument :document_locale, String, required: false
      argument :document_numbering, Types::BillingEntities::DocumentNumberingEnum, required: false
      argument :invoice_footer, String, required: false
      argument :invoice_grace_period, Integer, required: false
      argument :subscription_invoice_issuing_date_adjustment, Types::BillingEntities::SubscriptionInvoiceIssuingDateAdjustmentEnum, required: false
      argument :subscription_invoice_issuing_date_anchor, Types::BillingEntities::SubscriptionInvoiceIssuingDateAnchorEnum, required: false
    end
  end
end
