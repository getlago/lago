# frozen_string_literal: true

module Types
  module ApiLogs
    class HttpMethodEnum < Types::BaseEnum
      description "Api Logs http method enums"

      Clickhouse::ApiLog::HTTP_METHODS.keys.without(:get).each do |key|
        value key
      end
    end
  end
end
