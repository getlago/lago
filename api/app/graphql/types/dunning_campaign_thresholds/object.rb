# frozen_string_literal: true

module Types
  module DunningCampaignThresholds
    class Object < Types::BaseObject
      graphql_name "DunningCampaignThreshold"

      field :id, ID, null: false

      field :amount_cents, GraphQL::Types::BigInt, null: false
      field :currency, Types::CurrencyEnum, null: false
    end
  end
end
