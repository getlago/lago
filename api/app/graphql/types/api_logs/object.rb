# frozen_string_literal: true

module Types
  module ApiLogs
    class Object < Types::BaseObject
      graphql_name "ApiLog"
      description "Base api log"

      field :api_key, Types::ApiKeys::SanitizedObject
      field :api_version, String
      field :client, String
      field :http_method, Types::ApiLogs::HttpMethodEnum, null: false
      field :http_status, Integer, null: false
      field :request_body, GraphQL::Types::JSON
      field :request_id, ID, null: false
      field :request_origin, String
      field :request_path, String
      field :request_response, GraphQL::Types::JSON, null: false

      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :logged_at, GraphQL::Types::ISO8601DateTime, null: false

      # TODO: remove this once we have a proper way to handle JSON in Clickhouse
      # https://github.com/PNixx/clickhouse-activerecord/pull/192
      def request_body
        deep_json_parser(object.request_body)
      end

      def request_response
        deep_json_parser(object.request_response)
      end

      def deep_json_parser(attribute)
        attribute.transform_values do |value|
          parsed = value.is_a?(String) ? JSON.parse(value) : value
          (parsed.is_a?(Array) || parsed.is_a?(Hash)) ? parsed : value
        rescue JSON::ParserError
          value
        end
      end
    end
  end
end
