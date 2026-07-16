# frozen_string_literal: true

module Types
  module DataExports
    module Invoices
      class ExportTypeEnum < Types::BaseEnum
        graphql_name "InvoiceExportTypeEnum"

        value "invoices"
        value "invoice_fees"
      end
    end
  end
end
