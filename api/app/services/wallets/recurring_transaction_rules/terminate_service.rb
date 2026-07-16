# frozen_string_literal: true

module Wallets
  module RecurringTransactionRules
    class TerminateService < BaseService
      Result = BaseResult[:recurring_transaction_rule]

      def initialize(recurring_transaction_rule:)
        @recurring_transaction_rule = recurring_transaction_rule
        super
      end

      def call
        return result.not_found_failure!(resource: "recurring_transaction_rule") unless recurring_transaction_rule

        unless recurring_transaction_rule.terminated?
          recurring_transaction_rule.mark_as_terminated!
        end

        result.recurring_transaction_rule = recurring_transaction_rule
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :recurring_transaction_rule
    end
  end
end
