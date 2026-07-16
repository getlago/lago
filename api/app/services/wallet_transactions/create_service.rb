# frozen_string_literal: true

module WalletTransactions
  class CreateService < BaseService
    Result = BaseResult[:wallet_transaction]

    def initialize(wallet:, wallet_credit:, **transaction_params)
      @wallet = wallet
      @wallet_credit = wallet_credit
      @transaction_params = transaction_params

      super
    end

    def call
      transaction = wallet.wallet_transactions.create!(
        **transaction_params.slice(
          :credit_note_id,
          :invoice_id,
          :invoice_requires_successful_payment,
          :name,
          :priority,
          :settled_at,
          :source,
          :status,
          :transaction_type,
          :transaction_status,
          :voided_invoice_id
        ),
        organization_id: wallet.organization_id,
        billing_entity_id: billing_entity_id_for_snapshot,
        amount:,
        credit_amount:,
        metadata: transaction_params[:metadata] || [],
        remaining_amount_cents: initial_remaining_amount_cents
      )

      if transaction_params[:payment_method].present?
        transaction.payment_method_type = transaction_params[:payment_method][:payment_method_type] if transaction_params[:payment_method].key?(:payment_method_type)
        transaction.payment_method_id = transaction_params[:payment_method][:payment_method_id] if transaction_params[:payment_method].key?(:payment_method_id)
        transaction.save!
      end

      result.wallet_transaction = transaction

      result
    end

    private

    attr_reader :wallet, :wallet_credit, :transaction_params

    delegate :credit_amount, :amount, to: :wallet_credit

    def initial_remaining_amount_cents
      return nil unless wallet.traceable?
      return nil unless transaction_params[:transaction_type]&.to_sym == :inbound
      return nil unless transaction_params[:transaction_status]&.to_sym == :granted

      wallet_credit.amount_cents
    end

    def billing_entity_id_for_snapshot
      transaction_params[:billing_entity_id] || wallet.billing_entity&.id
    end
  end
end
