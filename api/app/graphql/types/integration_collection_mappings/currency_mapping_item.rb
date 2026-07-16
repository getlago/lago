# frozen_string_literal: true

module Types
  module IntegrationCollectionMappings
    class CurrencyMappingItem < Types::BaseObject
      field :currency_code, Types::CurrencyEnum, null: false
      field :currency_external_code, String, null: false
    end
  end
end
