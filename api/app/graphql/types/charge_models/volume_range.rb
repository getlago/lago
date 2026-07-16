# frozen_string_literal: true

module Types
  module ChargeModels
    class VolumeRange < Types::BaseObject
      field :from_value, GraphQL::Types::BigInt, null: false
      field :to_value, GraphQL::Types::BigInt, null: true

      field :flat_amount, String, null: false
      field :per_unit_amount, String, null: false
    end
  end
end
