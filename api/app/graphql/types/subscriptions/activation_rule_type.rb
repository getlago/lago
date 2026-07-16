# frozen_string_literal: true

module Types
  module Subscriptions
    class ActivationRuleType < Types::BaseObject
      graphql_name "SubscriptionActivationRule"

      field :id, ID, null: false
      field :status, Types::Subscriptions::ActivationRuleStatusEnum, null: false
      field :timeout_hours, Integer, null: true
      field :type, Types::Subscriptions::ActivationRuleTypeEnum, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :expires_at, GraphQL::Types::ISO8601DateTime, null: true
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end
