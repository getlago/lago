# frozen_string_literal: true

module Types
  module Entitlement
    class FeatureObject < Types::BaseObject
      field :id, ID, null: false

      field :code, String, null: false
      field :description, String, null: true
      field :name, String, null: true

      field :privileges, [Types::Entitlement::PrivilegeObject], null: false

      field :subscriptions_count, Integer, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
