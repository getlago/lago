# frozen_string_literal: true

module Types
  module Invoices
    module AppliedTaxes
      class Object < Types::BaseObject
        graphql_name "InvoiceAppliedTax"
        implements Types::Taxes::AppliedTax

        field :applied_on_whole_invoice, GraphQL::Types::Boolean, null: false, method: :applied_on_whole_invoice?
        field :enumed_tax_code, Types::Invoices::AppliedTaxes::WholeInvoiceApplicableTaxCodeEnum, null: true
        field :fees_amount_cents, GraphQL::Types::BigInt, null: false
        field :invoice, Types::Invoices::Object, null: false
        field :taxable_amount_cents, GraphQL::Types::BigInt, null: false

        def enumed_tax_code
          object.tax_code if object.applied_on_whole_invoice?
        end
      end
    end
  end
end
