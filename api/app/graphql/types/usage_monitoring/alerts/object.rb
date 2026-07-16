# frozen_string_literal: true

module Types
  module UsageMonitoring
    module Alerts
      class Object < Types::BaseObject
        graphql_name "Alert"

        field :id, ID, null: false

        field :alert_type, AlertTypeEnum, null: false
        field :billable_metric, Types::BillableMetrics::Object
        field :billable_metric_id, ID
        field :direction, DirectionEnum, null: false
        field :subscription_external_id, String
        field :wallet_id, String

        field :code, String, null: false
        field :name, String

        field :thresholds, [Types::UsageMonitoring::Alerts::ThresholdObject]

        field :created_at, GraphQL::Types::ISO8601DateTime, null: false
        field :deleted_at, GraphQL::Types::ISO8601DateTime
        field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
      end
    end
  end
end
