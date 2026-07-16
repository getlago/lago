# frozen_string_literal: true

module WalletTransactions
  class CreateFromParamsService < ::BaseService
    MAX_WALLET_UPDATE_ATTEMPTS = 5

    Result = BaseResult[:current_wallet, :wallet_transactions, :payment_method]

    def initialize(organization:, params:)
      @organization = organization
      @params = params

      @update_attempts = 0

      super
    end

    def call
      @update_attempts += 1

      # Normalize metadata
      params[:metadata] = [] if params[:metadata] == {}
      return result unless valid? # NOTE: validator sets result.current_wallet

      wallet_transactions = []
      @source = params[:source] || :manual
      @metadata = params[:metadata] || []
      @priority = params[:priority] || 50
      invoice_requires_successful_payment = if params.key?(:invoice_requires_successful_payment)
        ActiveModel::Type::Boolean.new.cast(params[:invoice_requires_successful_payment])
      end
      invoice_requires_successful_payment = result.current_wallet.invoice_requires_successful_payment if invoice_requires_successful_payment.nil?
      wallet = result.current_wallet

      ActiveRecord::Base.transaction do
        if params[:paid_credits]
          transaction = handle_paid_credits(
            wallet:,
            credits_amount: BigDecimal(params[:paid_credits]).floor(5),
            invoice_requires_successful_payment:
          )
          wallet_transactions << transaction
        end

        if params[:granted_credits]
          transaction = handle_granted_credits(
            wallet:,
            credits_amount: BigDecimal(params[:granted_credits]).floor(5),
            reset_consumed_credits: ActiveModel::Type::Boolean.new.cast(params[:reset_consumed_credits]),
            voided_invoice_id: params[:voided_invoice_id]
          )
          wallet_transactions << transaction
        end

        if params[:voided_credits]
          wallet_transactions << handle_voided_credits(wallet)
        end

        if params[:invoice_custom_section]
          wallet_transactions.compact.each do |wt|
            InvoiceCustomSections::AttachToResourceService.call(resource: wt, params:)
          end
        end
      end

      transactions = wallet_transactions.compact

      transactions.each do |wt|
        wt.reload
        SendWebhookJob.perform_later("wallet_transaction.created", wt)
        Utils::ActivityLog.produce(wt, "wallet_transaction.created")
      end

      result.wallet_transactions = transactions
      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::StaleObjectError
      if @update_attempts <= MAX_WALLET_UPDATE_ATTEMPTS
        sleep(rand(0.1..0.5))
        result.current_wallet.reload # Make sure the wallet is reloaded before retrying
        retry
      end

      raise
    end

    private

    attr_reader :organization, :params, :source, :metadata, :priority

    def name
      params[:name].presence
    end

    def handle_voided_credits(wallet)
      credit_amount = BigDecimal(params[:voided_credits]).floor(5)
      wallet_credit = WalletCredit.new(wallet:, credit_amount:, invoiceable: false)
      void_params = params.to_h.symbolize_keys.slice(:metadata, :source, :priority).merge(name:)
      WalletTransactions::VoidService.call!(wallet:, wallet_credit:, **void_params).wallet_transaction
    end

    def handle_paid_credits(wallet:, credits_amount:, invoice_requires_successful_payment:)
      return if credits_amount.zero?

      Validators::WalletTransactionAmountLimitsValidator.new(
        result,
        wallet:,
        credits_amount: credits_amount.to_s,
        ignore_validation: params[:ignore_paid_top_up_limits]
      ).raise_if_invalid!

      wallet_credit = WalletCredit.new(wallet:, credit_amount: credits_amount)
      wallet_transaction = WalletTransactions::CreateService.call!(
        wallet:,
        wallet_credit:,
        transaction_type: :inbound,
        status: :pending,
        source:,
        transaction_status: :purchased,
        invoice_requires_successful_payment:,
        metadata:,
        priority:,
        name:,
        payment_method: params[:payment_method]
      ).wallet_transaction

      BillPaidCreditJob.perform_after_commit(wallet_transaction, Time.current.to_i)

      wallet_transaction
    end

    def handle_granted_credits(wallet:, credits_amount:, reset_consumed_credits: false, voided_invoice_id: nil)
      return if credits_amount.zero?

      wallet_credit = WalletCredit.new(wallet:, credit_amount: credits_amount)
      ActiveRecord::Base.transaction do
        wallet_transaction = WalletTransactions::CreateService.call!(
          wallet:,
          wallet_credit:,
          transaction_type: :inbound,
          status: :settled,
          settled_at: Time.current,
          source:,
          transaction_status: :granted,
          metadata:,
          priority:,
          name:,
          voided_invoice_id:
        ).wallet_transaction

        Wallets::Balance::IncreaseService.new(
          wallet:,
          wallet_transaction:,
          reset_consumed_credits:
        ).call

        wallet_transaction
      end
    end

    def valid?
      result.payment_method = payment_method

      validate_params = params.merge(organization: organization)
      WalletTransactions::ValidateService.new(result, **validate_params).valid?
    end

    def payment_method
      return @payment_method if defined? @payment_method
      return nil if params[:payment_method].blank? || params[:payment_method][:payment_method_id].blank?

      @payment_method = PaymentMethod.find_by(id: params[:payment_method][:payment_method_id], organization_id: organization.id)
    end
  end
end
