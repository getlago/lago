# frozen_string_literal: true

module WalletTransactions
  class RecreditService < BaseService
    Result = BaseResult[:wallet_transaction]

    def initialize(wallet_transaction:)
      @wallet_transaction = wallet_transaction
      @wallet = wallet_transaction.wallet
      @customer = @wallet.customer

      super
    end

    def call
      result.wallet_transaction = wallet_transaction

      return result.not_allowed_failure!(code: "wallet_not_active") unless wallet.active?

      # Only relevant for historical data: zero-rounding amounts are now blocked at creation,
      # so this guards transactions created before that change. We return a success result so
      # that voiding an invoice never fails because of such old transactions.
      return result if WalletCredit.rounds_to_zero?(wallet:, credit_amount: wallet_transaction.credit_amount)

      transaction_result = WalletTransactions::CreateFromParamsService.call(
        organization: customer.organization,
        params: {
          wallet_id: wallet.id,
          granted_credits: wallet_transaction.credit_amount.to_s,
          reset_consumed_credits: true,
          voided_invoice_id: wallet_transaction.invoice_id
        }
      )

      return transaction_result unless transaction_result.success?

      result
    end

    private

    attr_reader :wallet_transaction, :wallet, :customer
  end
end
