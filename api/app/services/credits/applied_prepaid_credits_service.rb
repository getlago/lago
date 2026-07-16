# frozen_string_literal: true

module Credits
  class AppliedPrepaidCreditsService < BaseService
    Result = BaseResult[:prepaid_credit_amount_cents, :wallet_transactions]

    def initialize(invoice:)
      @invoice = invoice

      super(nil)
    end

    def call
      if wallets_already_applied?
        return result.service_failure!(code: "already_applied", message: "Prepaid credits already applied")
      end

      result.prepaid_credit_amount_cents ||= 0
      result.wallet_transactions ||= []

      return result if wallets.empty?

      ActiveRecord::Base.transaction do
        Customers::LockService.call(customer:, scope: :prepaid_credit) do
          # per each wallet we create a single wallet transaction. wallets_transaction_amounts is a hash with wallet and total transaction amount
          wallets_transaction_amounts = AllocatePrepaidCreditsByWalletsService.call!(invoice:).wallet_transactions

          wallets_transaction_amounts.each do |wallet, amount_cents|
            wallet_transaction = create_wallet_transaction(wallet, amount_cents)
            if wallet.traceable?
              WalletTransactions::TrackConsumptionService.call!(outbound_wallet_transaction: wallet_transaction)
            end
            Wallets::Balance::DecreaseService.call(wallet:, wallet_transaction:, skip_refresh: true)

            result.wallet_transactions << wallet_transaction
          end

          update_prepaid_credit_amounts(result.wallet_transactions)
          Customers::RefreshWalletsService.call(customer:, include_generating_invoices: true)
          invoice.save! if invoice.changed?
        end
      end

      schedule_webhook_notifications(result.wallet_transactions)
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :invoice

    delegate :customer, to: :invoice

    def schedule_webhook_notifications(wallet_transactions)
      wallet_transactions.each do |wt|
        Utils::ActivityLog.produce_after_commit(wt, "wallet_transaction.created")
        SendWebhookJob.perform_after_commit("wallet_transaction.created", wt)
      end
    end

    def update_prepaid_credit_amounts(wallet_transactions)
      return if wallet_transactions.empty?

      total_amount = wallet_transactions.sum(&:amount_cents)
      result.prepaid_credit_amount_cents += total_amount
      invoice.prepaid_credit_amount_cents += total_amount

      calculate_prepaid_credit_breakdown(wallet_transactions)
    end

    def calculate_prepaid_credit_breakdown(wallet_transactions)
      return unless invoice.customer.wallets.all?(&:traceable?)

      granted_amount = 0
      purchased_amount = 0

      consumptions = WalletTransactionConsumption
        .where(outbound_wallet_transaction_id: wallet_transactions.map(&:id))
        .includes(:inbound_wallet_transaction)

      consumptions.each do |consumption|
        if consumption.inbound_wallet_transaction.granted?
          granted_amount += consumption.consumed_amount_cents
        else
          purchased_amount += consumption.consumed_amount_cents
        end
      end

      invoice.prepaid_granted_credit_amount_cents = granted_amount if granted_amount > 0
      invoice.prepaid_purchased_credit_amount_cents = purchased_amount if purchased_amount > 0
    end

    def create_wallet_transaction(wallet, amount_cents)
      wallet_credit = WalletCredit.from_amount_cents(wallet:, amount_cents:)

      result = WalletTransactions::CreateService.call!(
        wallet:,
        wallet_credit:,
        invoice_id: invoice.id,
        transaction_type: :outbound,
        status: :settled,
        settled_at: Time.current,
        transaction_status: :invoiced
      )
      result.wallet_transaction
    end

    def wallets
      @wallets ||= begin
        scope = customer.wallets.active.includes(:wallet_targets).with_positive_balance
        scope = scope.where(balance_currency: invoice.currency) if invoice.currency.present?
        scope.in_application_order
      end
    end

    def wallets_already_applied?
      return false unless invoice
      return false unless invoice.persisted?

      WalletTransaction.exists?(invoice_id: invoice.id, wallet_id: wallets.map(&:id))
    end
  end
end
