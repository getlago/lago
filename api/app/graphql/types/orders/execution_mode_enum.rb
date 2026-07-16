# frozen_string_literal: true

module Types
  module Orders
    class ExecutionModeEnum < Types::BaseEnum
      graphql_name "OrderExecutionModeEnum"

      Order::EXECUTION_MODES.each_key do |type|
        value type
      end
    end
  end
end
