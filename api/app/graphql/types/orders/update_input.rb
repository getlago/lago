# frozen_string_literal: true

module Types
  module Orders
    class UpdateInput < Types::BaseInputObject
      description "Update Order input arguments"

      argument :execute_at, GraphQL::Types::ISO8601DateTime, required: false
      argument :execution_mode, Types::Orders::ExecutionModeEnum, required: false
      argument :id, ID, required: true
    end
  end
end
