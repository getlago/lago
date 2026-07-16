# frozen_string_literal: true

class BackfillInvoicesAndPayments < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    update_invoices
    update_payments
  end

  def down
  end

  private

  # Inline model and constants definitions to avoid future dependency issues
  class Invoice < ApplicationRecord
    self.table_name = "invoices"
    PAYMENT_STATUS = {pending: 0, succeeded: 1, failed: 2}.freeze
  end

  class Payment < ApplicationRecord
    self.table_name = "payments"
    belongs_to :payment_provider, optional: true

    PAYABLE_PAYMENT_STATUS = {
      pending: "pending",
      processing: "processing",
      succeeded: "succeeded",
      failed: "failed"
    }.freeze
  end

  class PaymentProvider < ApplicationRecord
    self.table_name = "payment_providers"
  end

  def update_invoices
    Invoice.where(payment_status: Invoice::PAYMENT_STATUS[:succeeded])
      .update_all("total_paid_amount_cents = total_amount_cents") # rubocop:disable Rails/SkipsModelValidations
  end

  def update_payments
    provider_statuses = {
      "PaymentProviders::AdyenProvider" => {
        processing: %w[AuthorisedPending Received],
        succeeded: %w[Authorised SentForSettle SettleScheduled Settled Refunded],
        failed: %w[Cancelled CaptureFailed Error Expired Refused]
      },
      "PaymentProviders::CashfreeProvider" => {
        processing: %w[PARTIALLY_PAID],
        succeeded: %w[PAID],
        failed: %w[EXPIRED CANCELLED]
      },
      "PaymentProviders::GocardlessProvider" => {
        processing: %w[pending_customer_approval pending_submission submitted confirmed],
        succeeded: %w[paid_out],
        failed: %w[cancelled customer_approval_denied failed charged_back]
      },
      "PaymentProviders::StripeProvider" => {
        processing: %w[processing requires_capture requires_action requires_confirmation],
        succeeded: %w[succeeded],
        failed: %w[canceled requires_payment_method]
      }
    }

    provider_statuses.each do |provider_type, statuses|
      update_payment_status(provider_type, statuses[:processing], Payment::PAYABLE_PAYMENT_STATUS[:processing])
      update_payment_status(provider_type, statuses[:succeeded], Payment::PAYABLE_PAYMENT_STATUS[:succeeded])
      update_payment_status(provider_type, statuses[:failed], Payment::PAYABLE_PAYMENT_STATUS[:failed])
    end
  end

  def update_payment_status(provider_type, statuses, new_status)
    # some payments providers are already deleted but we still need to change the payment
    Payment.left_joins(:payment_provider)
      .where("payment_providers.type = ? OR payment_providers.id IS NULL", provider_type)
      .where(payable_payment_status: nil, status: statuses)
      .update_all(payable_payment_status: new_status) # rubocop:disable Rails/SkipsModelValidations
  end
end
