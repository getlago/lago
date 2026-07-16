# frozen_string_literal: true

module Types
  module OrderForms
    class MarkAsSignedInput < Types::BaseInputObject
      description "Mark Order Form as signed input arguments"

      argument :execute_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :execution_mode, Types::Orders::ExecutionModeEnum, required: false
      argument :id, ID, required: true
      argument :signed_document, String, required: false
    end
  end
end
