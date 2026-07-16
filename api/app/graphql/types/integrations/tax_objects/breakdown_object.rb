# frozen_string_literal: true

module Types
  module Integrations
    module TaxObjects
      class BreakdownObject < Types::BaseObject
        graphql_name "TaxBreakdownObject"

        # we need to show how this tax will behave when invoice is generated - will it be applied
        # on whole invoice specific rule or just a normal tax
        field :enumed_tax_code, Types::Invoices::AppliedTaxes::WholeInvoiceApplicableTaxCodeEnum, null: true
        field :name, String, null: true
        field :rate, GraphQL::Types::Float, null: true
        field :tax_amount, GraphQL::Types::BigInt, null: true
        field :type, String, null: true

        def rate
          BigDecimal(object.rate)
        end

        def tax_code
          @tax_code ||= object.name&.parameterize(separator: "_")
        end

        def enumed_tax_code
          tax_code if Invoice::AppliedTax::TAX_CODES_APPLICABLE_ON_WHOLE_INVOICE.include?(tax_code)
        end
      end
    end
  end
end
