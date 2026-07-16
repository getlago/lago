# frozen_string_literal: true

module Types
  module Customers
    module Metadata
      class Input < Types::BaseInputObject
        graphql_name "CustomerMetadataInput"

        argument :id, ID, required: false
        argument :key, String, required: true
        argument :value, String, required: true

        argument :display_in_invoice, Boolean, required: true
      end
    end
  end
end
