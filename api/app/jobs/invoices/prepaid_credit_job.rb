# frozen_string_literal: true

module Invoices
  class PrepaidCreditJob < ApplicationJob
    queue_as "high_priority"

    retry_on ActiveRecord::StaleObjectError, wait: :polynomially_longer, attempts: 6
    unique :until_executed, on_conflict: :log

    def lock_key_arguments
      invoice = arguments.first
      payment_status = arguments.second || :succeeded

      [invoice, payment_status.to_sym]
    end

    def perform(invoice, payment_status = :succeeded)  # Default to :succeeded for old jobs
      wallet_transaction = invoice.fees.find_by(fee_type: "credit")&.invoiceable

      if should_grant_prepaid_credits?(invoice, payment_status.to_sym)
        Wallets::ApplyPaidCreditsService.call(wallet_transaction:)
        Invoices::FinalizeOpenCreditService.call(invoice:)
      else
        WalletTransactions::MarkAsFailedService.call(wallet_transaction:)
      end
    end

    private

    # This job also runs when an invoice is marked as paid because it was fully settled by credit note
    # with offset. This occurs when a credit note is applied to the original invoice (offset value)
    # instead of to future invoices.
    #
    # In this scenario, the invoice is not paid via a payment, but via a credit note,
    # so no pre-paid credits should be added to the customer's wallet.
    def should_grant_prepaid_credits?(invoice, payment_status)
      payment_status == :succeeded && !paid_by_credit_note?(invoice)
    end

    # For credit invoices, the credit note is always issued for the full invoice amount.
    # That means we don't need to compare amounts here.
    #
    # If the invoice has any invoice_settlements of type credit_note, it indicates the invoice
    # was fully settled by a credit note (not by a payment).
    def paid_by_credit_note?(invoice)
      invoice.invoice_settlements.where(settlement_type: :credit_note).exists?
    end
  end
end
