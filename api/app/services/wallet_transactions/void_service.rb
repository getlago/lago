# frozen_string_literal: true

module WalletTransactions
  class VoidService < BaseService
    Result = BaseResult[:wallet_transaction]

    def initialize(wallet:, wallet_credit:, inbound_wallet_transaction: nil, **transaction_params)
      @wallet = wallet
      @wallet_credit = wallet_credit
      @inbound_wallet_transaction = inbound_wallet_transaction
      @transaction_params = transaction_params.slice(
        :source,
        :metadata,
        :priority,
        :credit_note_id,
        :name
      )

      super
    end

    def call
      return result if wallet_credit.credit_amount.zero?
      return result unless valid?

      ActiveRecord::Base.transaction do
        Customers::LockService.call(customer:, scope: :prepaid_credit) do
          wallet.reload
          wallet_transaction = CreateService.call!(
            wallet:,
            wallet_credit:,
            transaction_type: :outbound,
            status: :settled,
            settled_at: Time.current,
            transaction_status: :voided,
            billing_entity_id: inbound_wallet_transaction&.billing_entity_id,
            **transaction_params
          ).wallet_transaction

          if wallet.traceable?
            TrackConsumptionService.call!(
              outbound_wallet_transaction: wallet_transaction,
              inbound_wallet_transaction_id: inbound_wallet_transaction&.id
            )
          end

          Wallets::Balance::DecreaseService.new(wallet:, wallet_transaction:).call
          result.wallet_transaction = wallet_transaction
        end
      end

      result
    end

    private

    attr_reader :wallet, :wallet_credit, :inbound_wallet_transaction, :transaction_params
    delegate :customer, to: :wallet

    def valid?
      return true unless wallet.traceable?
      return true unless inbound_wallet_transaction

      if wallet_credit.amount_cents > inbound_wallet_transaction.remaining_amount_cents
        result.single_validation_failure!(
          field: :amount_cents,
          error_code: "exceeds_remaining_transaction_amount"
        )
        return false
      end

      true
    end
  end
end
