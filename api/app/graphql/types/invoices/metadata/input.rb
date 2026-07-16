# frozen_string_literal: true

module Types
  module Invoices
    module Metadata
      class Input < Types::BaseInputObject
        description "Attributes for creating or updating invoice metadata object"
        graphql_name "InvoiceMetadataInput"

        argument :id, ID, required: false
        argument :key, String, required: true
        argument :value, String, required: true
      end
    end
  end
end
