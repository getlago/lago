# frozen_string_literal: true

module Types
  module Events
    class Object < Types::BaseObject
      graphql_name "Event"

      field :code, String, null: false
      field :id, ID, null: false

      field :external_subscription_id, String, null: true
      field :transaction_id, String, null: true

      field :customer_timezone, Types::TimezoneEnum, null: false
      field :deleted_at, GraphQL::Types::ISO8601DateTime, null: true
      field :received_at, GraphQL::Types::ISO8601DateTime, null: true, method: :created_at
      field :timestamp, GraphQL::Types::ISO8601DateTime, null: true

      field :api_client, String, null: true
      field :ip_address, String, null: true

      field :billable_metric_name, String, null: true
      field :payload, GraphQL::Types::JSON, null: false

      field :match_billable_metric, Boolean, null: true
      field :match_custom_field, Boolean, null: true
      field :match_customer, Boolean, null: true
      field :match_subscription, Boolean, null: true

      def payload
        {
          event: {
            transaction_id: object.transaction_id,
            external_subscription_id: object.external_subscription_id,
            code: object.code,
            timestamp: object.timestamp.to_i,
            properties: object.properties || {}
          }
        }
      end

      def match_billable_metric
        object.billable_metric.present?
      end

      def match_custom_field
        return true if object.billable_metric.blank?
        return true if object.billable_metric.field_name.blank?

        object.properties.key?(object.billable_metric.field_name)
      end

      def customer_timezone
        object.customer&.applicable_timezone || object.organization.timezone || "UTC"
      end

      def billable_metric_name
        object.billable_metric&.name
      end

      def match_customer
        object.customer_id.present?
      end

      def match_subscription
        object.subscription_id.present?
      end
    end
  end
end
