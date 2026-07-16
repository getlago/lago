# frozen_string_literal: true

module Invoices
  class PaidCreditService < BaseService
    def initialize(wallet_transaction:, timestamp:, invoice: nil)
      @customer = wallet_transaction.wallet.customer
      @wallet_transaction = wallet_transaction
      @timestamp = timestamp

      # NOTE: In case of retry when the creation process failed,
      #       and if the generating invoice was persisted,
      #       the process can be retried without creating a new invoice
      @invoice = invoice

      super
    end

    def call
      create_generating_invoice unless invoice
      result.invoice = invoice

      wallet_transaction.update!(invoice: result.invoice)

      ActiveRecord::Base.transaction do
        create_credit_fee(invoice)
        compute_amounts(invoice)
        Invoices::ApplyInvoiceCustomSectionsService.call(invoice:, resources: [wallet_transaction.invoice_custom_section_resource])

        if License.premium? && wallet_transaction.invoice_requires_successful_payment?
          invoice.open!
        else
          Invoices::FinalizeService.call!(invoice: invoice)
        end
      end

      if invoice.finalized?
        Utils::SegmentTrack.invoice_created(result.invoice)
        SendWebhookJob.perform_later("invoice.paid_credit_added", result.invoice)
        Utils::ActivityLog.produce(invoice, "invoice.paid_credit_added")
        GenerateDocumentsJob.perform_later(invoice:, notify: should_deliver_email?)
        Integrations::Aggregator::Invoices::CreateJob.perform_later(invoice:) if invoice.should_sync_invoice?
        Integrations::Aggregator::Invoices::Hubspot::CreateJob.perform_later(invoice:) if invoice.should_sync_hubspot_invoice?
      end

      create_payment(result.invoice)

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue Sequenced::SequenceError
      raise
    rescue => e
      result.fail_with_error!(e)
    end

    private

    attr_accessor :customer, :timestamp, :wallet_transaction, :invoice

    def currency
      @currency ||= wallet_transaction.wallet.currency
    end

    def create_generating_invoice
      invoice_result = Invoices::CreateGeneratingService.call(
        customer:,
        invoice_type: :credit,
        currency:,
        datetime: Time.zone.at(timestamp),
        billing_entity: wallet_transaction.billing_entity || wallet_transaction.wallet.billing_entity || customer.billing_entity
      )
      invoice_result.raise_if_error!

      @invoice = invoice_result.invoice
    end

    def compute_amounts(invoice)
      fee_amounts = invoice.fees.select(:amount_cents, :taxes_amount_cents)

      invoice.currency = currency
      invoice.fees_amount_cents = fee_amounts.sum(:amount_cents)
      invoice.sub_total_excluding_taxes_amount_cents = invoice.fees_amount_cents
      invoice.taxes_amount_cents = fee_amounts.sum(:taxes_amount_cents)
      invoice.sub_total_including_taxes_amount_cents = (
        invoice.sub_total_excluding_taxes_amount_cents + invoice.taxes_amount_cents
      )
      invoice.total_amount_cents = invoice.sub_total_including_taxes_amount_cents
    end

    def create_credit_fee(invoice)
      fee_result = Fees::PaidCreditService
        .new(invoice:, wallet_transaction:, customer:).create

      fee_result.raise_if_error!
    end

    def create_payment(invoice)
      Invoices::Payments::CreateService.call_async(invoice:)
    end

    def should_deliver_email?
      License.premium? &&
        invoice.billing_entity.email_settings.include?("invoice.finalized")
    end
  end
end
