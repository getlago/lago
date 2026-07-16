# frozen_string_literal: true

module Types
  module DunningCampaignThresholds
    class Input < Types::BaseInputObject
      graphql_name "DunningCampaignThresholdInput"

      argument :id, ID, required: false

      argument :amount_cents, GraphQL::Types::BigInt, required: true
      argument :currency, Types::CurrencyEnum, required: true
    end
  end
end
