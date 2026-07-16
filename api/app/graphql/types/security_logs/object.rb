# frozen_string_literal: true

module Types
  module SecurityLogs
    class Object < Types::BaseObject
      graphql_name "SecurityLog"
      description "Security log entry"

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :device_info, GraphQL::Types::JSON
      field :log_event, Types::SecurityLogs::LogEventEnum, null: false
      field :log_id, ID, null: false
      field :log_type, Types::SecurityLogs::LogTypeEnum, null: false
      field :logged_at, GraphQL::Types::ISO8601DateTime, null: false
      field :resources, GraphQL::Types::JSON
      field :user_email, String, null: true

      def user_email
        object.user&.email
      end
    end
  end
end
