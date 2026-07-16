# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class BaseInput < Types::BaseInputObject
      graphql_name "BaseIntegrationCollectionMappingInput"

      argument :external_account_code, String, required: false
      argument :external_id, String, required: false
      argument :external_name, String, required: false

      argument :tax_code, String, required: false
      argument :tax_nexus, String, required: false
      argument :tax_type, String, required: false

      argument :currencies, [CurrencyMappingItemInput], required: false,
        prepare: :convert_currencies_to_hash,
        validates: {::Validators::UniqueByFieldValidator => {field_name: :currency_code}}

      def convert_currencies_to_hash(value)
        value.map { |item| [item[:currency_code], item[:currency_external_code]] }.to_h
      end
    end
  end
end
