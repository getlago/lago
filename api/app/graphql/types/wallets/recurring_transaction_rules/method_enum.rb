# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class MethodEnum < Types::BaseEnum
        graphql_name "RecurringTransactionMethodEnum"

        RecurringTransactionRule::METHODS.each do |type|
          value type
        end
      end
    end
  end
end
