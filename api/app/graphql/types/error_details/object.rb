# frozen_string_literal: true

module Types
  module ErrorDetails
    class Object < Types::BaseObject
      graphql_name "ErrorDetail"

      field :error_code, Types::ErrorDetails::ErrorCodesEnum, null: false
      field :error_details, String, null: true
      field :id, ID, null: false

      def error_details
        object.details[object.error_code]
      end
    end
  end
end
