# frozen_string_literal: true

module Wallets
  class TerminateService < BaseService
    Result = BaseResult[:wallet]

    def initialize(wallet:)
      @wallet = wallet
      super
    end

    def call
      return result.not_found_failure!(resource: "wallet") unless wallet
      unless wallet.terminated?
        ActiveRecord::Base.transaction do
          wallet.mark_as_terminated!
          wallet.recurring_transaction_rules.find_each do |recurring_transaction_rule|
            Wallets::RecurringTransactionRules::TerminateService.call(recurring_transaction_rule: recurring_transaction_rule)
          end
          wallet.customer.flag_wallets_for_refresh
          SendWebhookJob.perform_after_commit("wallet.terminated", wallet)
        end
      end

      result.wallet = wallet
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :wallet
  end
end
