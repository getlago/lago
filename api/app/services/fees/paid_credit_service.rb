# frozen_string_literal: true

module Fees
  class PaidCreditService < BaseService
    def initialize(invoice:, wallet_transaction:, customer:)
      @invoice = invoice
      @customer = customer
      @wallet_transaction = wallet_transaction
      super(nil)
    end

    def create
      return result if already_billed?

      amount_cents = wallet_transaction.amount_cents
      precise_amount_cents = amount_cents.to_d
      unit_amount_cents = wallet_transaction.unit_amount_cents

      new_fee = Fee.new(
        invoice:,
        organization_id: invoice.organization_id,
        billing_entity_id: invoice.billing_entity_id,
        fee_type: :credit,
        invoiceable_type: "WalletTransaction",
        invoiceable: wallet_transaction,
        amount_cents:,
        precise_amount_cents:,
        amount_currency: wallet_transaction.wallet.currency,
        unit_amount_cents:,
        units: wallet_transaction.credit_amount,
        payment_status: :pending,

        # NOTE: No taxes should be applied on as it can be considered as an advance
        taxes_rate: 0,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.to_d
      )
      new_fee.precise_unit_amount = new_fee.unit_amount.to_f
      new_fee.save!

      result.fee = new_fee
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice, :wallet_transaction, :customer
    delegate :organization, to: :customer

    def already_billed?
      existing_fee = invoice.fees.find_by(invoiceable_id: wallet_transaction.id, invoiceable_type: "WalletTransaction")
      return false unless existing_fee

      result.fee = existing_fee
      true
    end
  end
end
