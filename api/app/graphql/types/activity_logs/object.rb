# frozen_string_literal: true

module Types
  module ActivityLogs
    class Object < Types::BaseObject
      graphql_name "ActivityLog"
      description "Base activity log"

      field :activity_id, ID, null: false
      field :activity_object, GraphQL::Types::JSON
      field :activity_object_changes, GraphQL::Types::JSON
      field :activity_source, Types::ActivityLogs::ActivitySourceEnum, null: false
      field :activity_type, Types::ActivityLogs::ActivityTypeEnum, null: false
      field :api_key, Types::ApiKeys::SanitizedObject
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :external_customer_id, String
      field :external_subscription_id, String
      field :logged_at, GraphQL::Types::ISO8601DateTime, null: false
      field :organization, Types::Organizations::OrganizationType
      field :resource, Types::ActivityLogs::ResourceObject
      field :user_email, String

      def user_email
        object.user&.email
      end

      # TODO: remove this once we have a proper way to handle JSON in Clickhouse
      # https://github.com/PNixx/clickhouse-activerecord/pull/192
      def activity_object
        object.activity_object.transform_values do |value|
          parsed = value.is_a?(String) ? JSON.parse(value) : value
          (parsed.is_a?(Array) || parsed.is_a?(Hash)) ? parsed : value
        rescue JSON::ParserError
          value
        end
      end

      # TODO: remove this once we have a proper way to handle JSON in Clickhouse
      # https://github.com/PNixx/clickhouse-activerecord/pull/192
      def activity_object_changes
        object.activity_object_changes.transform_values { |v| JSON.parse(v) }
      end
    end
  end
end
