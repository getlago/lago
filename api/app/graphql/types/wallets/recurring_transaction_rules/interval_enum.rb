# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class IntervalEnum < Types::BaseEnum
        graphql_name "RecurringTransactionIntervalEnum"

        RecurringTransactionRule::INTERVALS.each do |type|
          value type
        end
      end
    end
  end
end
