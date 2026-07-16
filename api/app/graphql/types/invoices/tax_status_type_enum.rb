# frozen_string_literal: true

module Types
  module Invoices
    class TaxStatusTypeEnum < Types::BaseEnum
      graphql_name "InvoiceTaxStatusTypeEnum"

      Invoice::TAX_STATUSES.keys.each do |type|
        value type
      end
    end
  end
end
