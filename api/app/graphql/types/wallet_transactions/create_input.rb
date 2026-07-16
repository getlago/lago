# frozen_string_literal: true

module Types
  module WalletTransactions
    class CreateInput < Types::BaseInputObject
      graphql_name "CreateCustomerWalletTransactionInput"

      argument :wallet_id, ID, required: true

      argument :granted_credits, String, required: false
      argument :ignore_paid_top_up_limits, Boolean, required: false
      argument :invoice_custom_section, Types::InvoiceCustomSections::ReferenceInput, required: false
      argument :invoice_requires_successful_payment, Boolean, required: false
      argument :metadata, [Types::WalletTransactions::MetadataInput], required: false
      argument :name, String, required: false
      argument :paid_credits, String, required: false
      argument :payment_method, Types::PaymentMethods::ReferenceInput, required: false
      argument :priority, Integer, required: false
      argument :voided_credits, String, required: false
    end
  end
end
