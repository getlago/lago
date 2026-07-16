# frozen_string_literal: true

module Invoices
  class RefreshDraftService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:, context: :refresh)
      @invoice = invoice
      @subscription_ids = invoice.subscriptions.pluck(:id)
      @context = context
      @invoice_subscriptions = invoice.invoice_subscriptions

      # NOTE: Recurring status (meaning billed automatically from the recurring billing process)
      #       should be kept to prevent double billing on billing day
      @recurring = invoice_subscriptions.first&.recurring || false

      # NOTE: upgrading is used as a not persisted reasong as it means
      #       one subscription starting and a second one terminating
      @invoicing_reason = if @recurring
        :subscription_periodic
      elsif invoice_subscriptions.count == 1
        invoice_subscriptions.first&.invoicing_reason&.to_sym || :upgrading
      else
        :upgrading
      end

      super
    end

    def call
      return result.forbidden_failure! unless invoice.subscription?

      result.invoice = invoice
      return result unless invoice.draft?

      ActiveRecord::Base.transaction do
        invoice.update!(ready_to_be_refreshed: false) if invoice.ready_to_be_refreshed?
        old_total_amount_cents = invoice.total_amount_cents

        old_fee_values = invoice_credit_note_items.map do |item|
          {credit_note_item_id: item.id, fee_amount_cents: item.fee&.amount_cents}
        end
        cn_subscription_ids = invoice.credit_notes.map do |cn|
          {credit_note_id: cn.id, subscription_id: cn.fees.pick(:subscription_id)}
        end
        timestamp = fetch_timestamp

        reset_invoice_values

        Invoices::CreateInvoiceSubscriptionService.call(
          invoice:,
          subscriptions: Subscription.find(subscription_ids),
          timestamp:,
          invoicing_reason:,
          refresh: true
        ).raise_if_error!

        calculate_result = Invoices::CalculateFeesService.call(
          invoice: invoice.reload,
          recurring:,
          context:
        )
        Invoices::ApplyInvoiceCustomSectionsService.call(invoice:)

        invoice.credit_notes.each do |credit_note|
          subscription_id = cn_subscription_ids.find { |h| h[:credit_note_id] == credit_note.id }[:subscription_id]
          fee = invoice.fees.subscription.find_by(subscription_id:)
          CreditNotes::RefreshDraftService.call(credit_note:, fee:, old_fee_values:)
        end

        calculate_result.raise_if_error! unless tax_error?(calculate_result.error)

        if old_total_amount_cents != invoice.total_amount_cents
          flag_lifetime_usage_for_refresh
          invoice.customer.flag_wallets_for_refresh
        end

        # NOTE: In case of a refresh the same day of the termination.
        invoice.fees.update_all(created_at: invoice.created_at) # rubocop:disable Rails/SkipsModelValidations

        return result if tax_error?(calculate_result.error) # rubocop:disable Rails/TransactionExitStatement

        if invoice.should_update_hubspot_invoice?
          Integrations::Aggregator::Invoices::Hubspot::UpdateJob.perform_later(invoice: invoice.reload)
        end
      end

      result
    rescue BaseService::FailedResult => e
      e.result
    end

    private

    attr_accessor :invoice, :subscription_ids, :invoicing_reason, :recurring, :context, :invoice_subscriptions

    def fetch_timestamp
      timestamp = invoice_subscriptions.first&.timestamp
      return timestamp if timestamp

      fee = invoice.fees.first
      # NOTE: Adding 1 second because of to_i rounding.
      return invoice.created_at + 1.second unless fee&.properties&.[]("timestamp")

      DateTime.parse(fee.properties["timestamp"])
    end

    def invoice_credit_note_items
      CreditNoteItem
        .joins(:credit_note)
        .where(credit_note: {invoice_id: invoice.id})
        .includes(:fee)
    end

    def flag_lifetime_usage_for_refresh
      LifetimeUsages::FlagRefreshFromInvoiceService.call(invoice:).raise_if_error!
    end

    def tax_error?(error)
      error&.is_a?(BaseService::UnknownTaxFailure)
    end

    def reset_invoice_values
      invoice.credit_notes.each { |cn| cn.items.update_all(fee_id: nil) } # rubocop:disable Rails/SkipsModelValidations
      invoice.fees.destroy_all
      invoice_subscriptions.destroy_all
      invoice.applied_taxes.destroy_all
      invoice.error_details.discard_all # rubocop:disable Lago/DiscardAll
      invoice.applied_invoice_custom_sections.destroy_all
      invoice.credits.progressive_billing_invoice_kind.destroy_all

      invoice.taxes_amount_cents = 0
      invoice.total_amount_cents = 0
      invoice.taxes_rate = 0
      invoice.fees_amount_cents = 0
      invoice.sub_total_excluding_taxes_amount_cents = 0
      invoice.sub_total_including_taxes_amount_cents = 0
      invoice.progressive_billing_credit_amount_cents = 0

      invoice.save!
    end
  end
end
