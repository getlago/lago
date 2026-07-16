# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class CurrencyMappingItemInput < Types::BaseInputObject
      argument :currency_code, Types::CurrencyEnum, required: true
      argument :currency_external_code, String, required: true
    end
  end
end
