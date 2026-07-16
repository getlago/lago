# frozen_string_literal: true

module Types
  module Invoices
    module AppliedTaxes
      class WholeInvoiceApplicableTaxCodeEnum < Types::BaseEnum
        graphql_name "InvoiceAppliedTaxOnWholeInvoiceCodeEnum"

        Invoice::AppliedTax::TAX_CODES_APPLICABLE_ON_WHOLE_INVOICE.each do |type|
          value type
        end
      end
    end
  end
end
