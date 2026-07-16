# frozen_string_literal: true

module Types
  module Customers
    module Metadata
      class Filter < Types::BaseInputObject
        graphql_name "CustomerMetadataFilter"

        argument :key, String, required: true
        argument :value, String, required: true
      end
    end
  end
end
