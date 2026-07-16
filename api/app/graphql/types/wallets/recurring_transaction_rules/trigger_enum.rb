# frozen_string_literal: true

module Types
  module Wallets
    module RecurringTransactionRules
      class TriggerEnum < Types::BaseEnum
        graphql_name "RecurringTransactionTriggerEnum"

        RecurringTransactionRule::TRIGGERS.each do |type|
          value type
        end
      end
    end
  end
end
