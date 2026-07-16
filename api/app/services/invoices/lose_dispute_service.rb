# frozen_string_literal: true

module Invoices
  class LoseDisputeService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:, payment_dispute_lost_at: nil, reason: nil)
      @invoice = invoice
      @payment_dispute_lost_at = payment_dispute_lost_at.presence || DateTime.current
      @reason = reason
      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") if invoice.nil?

      result.invoice = invoice

      invoice.mark_as_dispute_lost!(payment_dispute_lost_at)

      SendWebhookJob.perform_later("invoice.payment_dispute_lost", result.invoice, provider_error: reason)
      Invoices::ProviderTaxes::VoidJob.perform_later(invoice:)
      Integrations::Aggregator::Invoices::Hubspot::UpdateJob.perform_later(invoice:) if invoice.should_update_hubspot_invoice?

      result
    rescue ActiveRecord::RecordInvalid => _e
      result.not_allowed_failure!(code: "not_disputable")
    end

    private

    attr_reader :invoice, :payment_dispute_lost_at, :reason
  end
end
