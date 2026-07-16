# frozen_string_literal: true

module Wallets
  class ThresholdTopUpService < BaseService
    Result = BaseResult

    def initialize(wallet:)
      @wallet = wallet
      super
    end

    def call
      return result if rule.nil?
      return result if wallet.credits_ongoing_balance > rule.threshold_credits
      return result if (pending_transactions_amount + wallet.credits_ongoing_balance) > rule.threshold_credits

      params = {
        wallet_id: wallet.id,
        paid_credits: rule.compute_paid_credits(ongoing_balance: wallet.credits_ongoing_balance).to_s,
        granted_credits: rule.compute_granted_credits.to_s,
        source: :threshold,
        invoice_requires_successful_payment: rule.invoice_requires_successful_payment?,
        metadata: rule.transaction_metadata,
        name: rule.transaction_name,
        ignore_paid_top_up_limits: rule.ignore_paid_top_up_limits?
      }

      params[:invoice_custom_section] = rule.invoice_custom_section_params if rule.invoice_custom_section_params

      WalletTransactions::CreateJob.set(wait: 2.seconds).perform_later(
        organization_id: wallet.organization.id,
        params:,
        unique_transaction: true
      )

      result
    end

    private

    attr_reader :wallet

    def rule
      @rule ||= wallet.recurring_transaction_rules.active.where(trigger: :threshold).first
    end

    def pending_transactions_amount
      @pending_transactions_amount ||= wallet.wallet_transactions.pending.sum(:amount)
    end
  end
end
