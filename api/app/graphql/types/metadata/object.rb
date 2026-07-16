# frozen_string_literal: true

module Types
  module Metadata
    class Object < Types::BaseObject
      graphql_name "ItemMetadata"
      description "Metadata key-value pair"

      # metadata is stored as a jsonb object, so when sent as array it comes as array of [key, value] pairs
      field :key, String, null: false, method: :first
      field :value, String, null: true, method: :last
    end
  end
end
